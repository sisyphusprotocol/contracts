//SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import './interface/ICampaign.sol';

import 'hardhat/console.sol';

import { Consts } from './Consts.sol';

// TODO: merkle tree root to valid user, don't use enumerable

contract Campaign is ICampaign, Ownable, ERC721 {
  using SafeERC20 for IERC20;

  IERC20 private immutable _targetToken;
  uint256 private immutable _requiredAmount;
  Consts.CampaignStatus private _status;

  uint256 private _lastEpochEndTime;
  uint256 public currentEpoch;
  uint256 private _startTime;
  uint256 private _totalPeriod;
  uint256 private _period;

  uint256 public sharedReward;
  uint256 public hostReward;
  uint256 public protocolFee;
  address[] public allUsers;
  uint256 public successUsersCount;
  // Mapping from user address to position in the allUsers array
  mapping(address => uint256) private _allUserIndex;

  mapping(address => uint256) private _rewards;
  mapping(address => bool) public registry;

  struct Record {
    bytes32 contentUri;
  }

  // epoch => user => Record
  mapping(uint256 => mapping(address => Record)) public records;

  constructor(
    IERC20 token_,
    uint256 amount_,
    string memory name_,
    string memory symbol_,
    uint256 startTime_,
    uint256 totalPeriod_,
    uint256 periodLength_
  ) ERC721(name_, symbol_) {
    require(address(token_) != address(0), 'Campaign: invalid token');
    require(amount_ != 0, 'Campaign: invalid amount');
    _targetToken = token_;
    _requiredAmount = amount_;
    _startTime = startTime_;
    _lastEpochEndTime = startTime_;
    _totalPeriod = totalPeriod_;
    _period = periodLength_;
  }

  //
  /**
   * @dev user stake token and want to participate this campaign
   */
  function signUp() external override onlyNotStarted onlyEOA {
    IERC20(_targetToken).safeTransferFrom(msg.sender, address(this), _requiredAmount);
    _rewards[msg.sender] = _requiredAmount;
    emit EvSignUp(msg.sender);
  }

  /**
   * @dev user claim reward after campaign settled
   */
  function claim() external override {
    if (_status != Consts.CampaignStatus.SETTLED) {
      _settle();
    }

    uint256 reward = _rewards[msg.sender] + sharedReward / successUsersCount;

    IERC20(_targetToken).safeTransfer(msg.sender, reward);
    _rewards[msg.sender] = 0;

    emit EvClaimReward(msg.sender, reward);
  }

  /**
   * @dev host withdraw host reward
   */
  function withdraw() external onlyOwner onlySettled {
    uint256 reward = hostReward;
    hostReward = 0;
    IERC20(_targetToken).safeTransfer(msg.sender, reward);

    IERC20(_targetToken).safeTransferFrom(address(this), Consts.PROTOCOL_RECIPIENT, protocolFee);

    emit EvWithDraw(msg.sender, reward, protocolFee);
  }

  /**
   * @dev someone will call the function to settle the campaign
   */
  function _settle() private onlyEnded {
    for (uint256 i = 0; i < allUsers.length; i++) {
      successUsersCount = allUsers.length;
      address user = allUsers[i];
      for (uint256 j = 0; j < _totalPeriod; j++) {
        if (records[j][allUsers[i]].contentUri == bytes32(0)) {
          uint256 penalty = _rewards[user];
          hostReward = (penalty * Consts.HOST_REWARD) / Consts.DECIMAL;
          protocolFee = (penalty * Consts.PROTOCOL_FEE) / Consts.DECIMAL;
          sharedReward += penalty - hostReward - protocolFee;
          _rewards[user] = 0;
          successUsersCount -= 1;
          emit EvFailure(user);
        }
      }
    }
    _status = Consts.CampaignStatus.SETTLED;
  }

  /**
   * @dev user check in
   * @param contentUri bytes32 of ipfs uri or other decentralize storage
   */
  function checkIn(bytes32 contentUri) external override onlyRegistered {
    _checkEpoch();
    records[currentEpoch][msg.sender] = Record(contentUri);

    emit EvCheckIn(currentEpoch, msg.sender, contentUri);
  }

  function _checkEpoch() private {
    if (block.timestamp - _lastEpochEndTime > _period) {
      uint256 n = (block.timestamp - _lastEpochEndTime) / _period;
      currentEpoch += n;
      _lastEpochEndTime += _period * n;
    }
  }

  /**
   * @dev campaign owner admit several address to participate this campaign
   * @param allowlists allowed address array
   */
  function admit(address[] calldata allowlists) external onlyNotStarted onlyOwner {
    for (uint256 i = 0; i < allowlists.length; i++) {
      address user = allowlists[i];
      require(_rewards[user] == _requiredAmount, 'Campaign: not signed up');
      require(!registry[user], 'Campaign: already registered');
      registry[user] = true;

      _allUserIndex[user] = allUsers.length;
      allUsers.push(user);

      emit EvRegisterSuccessfully(user);
    }
  }

  /**
   * @dev once campaign owner admit some address by mistake
   * @dev can modify via this function but more gas-expensive
   * @param lists modified address list array
   * @param targetStatuses corresponding status array
   */
  function modifyRegistry(address[] calldata lists, bool[] calldata targetStatuses) external onlyNotStarted onlyOwner {
    for (uint256 i = 1; i < lists.length; i++) {
      address user = lists[i];
      bool targetStatus = targetStatuses[i];
      if (targetStatus) {
        require(!registry[user], 'Campaign: already registered');
        registry[user] = targetStatus;

        _allUserIndex[user] = allUsers.length;
        allUsers.push(user);
      } else {
        require(registry[user], 'Campaign: not yet registered');
        registry[user] = targetStatus;
        _deleteUserFromAllUsers(user);
      }
    }
    emit EvModifyRegistry(lists, targetStatuses);
  }

  function _deleteUserFromAllUsers(address user) private {
    uint256 lastUserIndex = allUsers.length - 1;
    uint256 userIndex = _allUserIndex[user];

    address lastUser = allUsers[lastUserIndex];

    allUsers[lastUserIndex] = lastUser;
    _allUserIndex[lastUser] = userIndex;

    delete _allUserIndex[user];
    allUsers.pop();
  }

  modifier onlySettled() {
    require(_status == Consts.CampaignStatus.SETTLED, 'Campaign: not settled');
    _;
  }

  modifier onlyEnded() {
    require(block.timestamp > _startTime + _totalPeriod * _period, 'Campaign: not ended');
    _;
  }

  modifier onlyNotStarted() {
    require(block.timestamp < _startTime, 'Campaign: already started');
    _;
  }

  modifier onlyRegistered() {
    require(registry[msg.sender], 'Campaign: not registered');
    _;
  }

  modifier onlyEOA() {
    require(!Address.isContract(msg.sender), 'Campaign: only EOA allowed');
    _;
  }
}
