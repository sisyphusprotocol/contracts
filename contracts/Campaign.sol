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

contract Campaign is ICampaign, Ownable, ERC721 {
  using SafeERC20 for IERC20;

  IERC20 public immutable targetToken;
  uint256 public immutable requiredAmount;
  Consts.CampaignStatus public _status;

  uint256 public lastEpochEndTime;
  uint256 public currentEpoch;
  uint256 public startTime;
  uint256 public length;
  uint256 public period;

  uint256 public sharedReward;
  address[] public allUsers;
  uint256 public successUsersCount;
  // Mapping from user address to position in the allUsers array
  mapping(address => uint256) private allUserIndex;

  mapping(address => uint256) public rewards;
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
    uint256 startTime_
  ) ERC721(name_, symbol_) {
    require(address(token_) != address(0), 'Campaign: invalid token');
    require(amount_ != 0, 'Campaign: invalid amount');
    targetToken = token_;
    requiredAmount = amount_;
    startTime = startTime_;
    lastEpochEndTime = startTime_;

    _status = Consts.CampaignStatus.NOT_START;

    length = 2;
    period = 86400;
  }

  /**
   * @dev user stake token and want to participate this campaign
   */
  function signUp() external override onlyNotStarted onlyEOA {
    IERC20(targetToken).safeTransferFrom(msg.sender, address(this), requiredAmount);
    rewards[msg.sender] = requiredAmount;
    emit EvRegisterRequest(msg.sender);
  }

  /**
   * @dev user claim reward after campaign settled
   */
  function claim() external {
    if (_status != Consts.CampaignStatus.SETTLED) {
      settle();
    }

    uint256 reward = rewards[msg.sender] + sharedReward / successUsersCount;

    IERC20(targetToken).safeTransfer(msg.sender, reward);
    rewards[msg.sender] = 0;
  }

  /**
   * @dev someone will call the function to settle the campaign
   */
  function settle() public onlyEnded {
    for (uint256 i = 0; i < allUsers.length; i++) {
      successUsersCount = allUsers.length;
      address user = allUsers[i];
      for (uint256 j = 0; j < length; j++) {
        if (records[j][allUsers[i]].contentUri == bytes32(0)) {
          sharedReward += rewards[user];
          rewards[user] = 0;
          successUsersCount -= 1;
        }
      }
    }
    _status = Consts.CampaignStatus.SETTLED;
  }

  /**
   * @dev user check in
   * @param contentUri bytes32 of ipfs uri or other decentralize storage
   */
  function checkIn(bytes32 contentUri) external onlyRegistered {
    _checkEpoch();
    records[currentEpoch][msg.sender] = Record(contentUri);
  }

  function _checkEpoch() private {
    if (block.timestamp - lastEpochEndTime > period) {
      uint256 n = (block.timestamp - lastEpochEndTime) / period;
      currentEpoch += n;
      lastEpochEndTime += period * n;
    }
  }

  /**
   * @dev campaign owner admit several address to participate this campaign
   * @param allowlists allowed address array
   */
  function admit(address[] calldata allowlists) external onlyNotStarted onlyOwner {
    for (uint256 i = 0; i < allowlists.length; i++) {
      address user = allowlists[i];
      require(rewards[user] == requiredAmount, 'Campaign: not signed up');
      require(!registry[user], 'Campaign: already registered');
      registry[user] = true;

      allUserIndex[user] = allUsers.length;
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
  function modifyRegistry(address[] calldata lists, bool[] calldata targetStatuses)
    external
    onlyNotStarted
    onlyOwner
    returns (bool)
  {
    for (uint256 i = 1; i < lists.length; i++) {
      address user = lists[i];
      bool targetStatus = targetStatuses[i];
      if (targetStatus) {
        require(!registry[user], 'Campaign: already registered');
        registry[user] = targetStatus;

        allUserIndex[user] = allUsers.length;
        allUsers.push(user);
      } else {
        require(registry[user], 'Campaign: not yet registered');
        registry[user] = targetStatus;
        _deleteUserFromAllUsers(user);
      }
    }
    return true;
  }

  function _deleteUserFromAllUsers(address user) private {
    uint256 lastUserIndex = allUsers.length - 1;
    uint256 userIndex = allUserIndex[user];

    address lastUser = allUsers[lastUserIndex];

    allUsers[lastUserIndex] = lastUser;
    allUserIndex[lastUser] = userIndex;

    delete allUserIndex[user];
    allUsers.pop();
  }

  modifier onlyEnded() {
    require(block.timestamp > startTime + length * period, 'Campaign: not ended');
    _;
  }

  modifier onlyNotStarted() {
    require(block.timestamp < startTime, 'Campaign: already started');
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
