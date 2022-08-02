//SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import './interface/ICampaign.sol';

import { Consts } from './Consts.sol';

contract Campaign is ICampaign, Ownable, ERC721 {
  using SafeERC20 for IERC20;

  IERC20 public immutable targetToken;
  uint256 public immutable requiredAmount;
  Consts.CampaignStatus public status;

  uint256 public lastEpochEndTime;
  uint256 public currentEpoch;
  uint256 public length;
  uint256 public period;

  mapping(address => uint256) public rewards;
  mapping(address => bool) public registry;

  struct Record {
    bytes32 contentUrl;
  }

  // epoch => user => Record
  mapping(uint256 => mapping(address => Record)) public records;

  constructor(
    Consts.CampaignType t,
    IERC20 token_,
    uint256 amount_,
    string memory name_,
    string memory symbol_
  ) ERC721(name_, symbol_) {
    require(address(token_) != address(0), 'Campaign: invalid token');
    require(amount_ != 0, 'Campaign: invalid amount');
    targetToken = token_;
    requiredAmount = amount_;
    status = Consts.CampaignStatus.NOT_START;

    length = 7;
    period = 86400;
  }

  /**
   * @dev user stake token and want to participate this campaign
   */
  function register() external override onlyStatus(Consts.CampaignStatus.NOT_START) onlyEOA {
    IERC20(targetToken).safeTransferFrom(msg.sender, address(this), requiredAmount);
    rewards[msg.sender] = requiredAmount;
    emit EvRegisterRequest(msg.sender);
  }

  function start() external onlyOwner onlyStatus(Consts.CampaignStatus.NOT_START) {
    lastEpochEndTime = block.timestamp;
    status = Consts.CampaignStatus.ON_GOING;
  }

  /**
   * @dev
   */
  function checkIn(bytes32 contentUrl) external {
    _checkEpoch();
    records[currentEpoch][msg.sender] = Record(contentUrl);
  }

  function _checkEpoch() internal {
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
  function admit(address[] calldata allowlists) external onlyStatus(Consts.CampaignStatus.NOT_START) onlyOwner {
    for (uint256 i = 1; i < allowlists.length; i++) {
      address user = allowlists[i];
      require(rewards[user] == requiredAmount, 'Campaign: not registered');
      registry[user] = true;
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
    onlyStatus(Consts.CampaignStatus.NOT_START)
    onlyOwner
    returns (bool)
  {
    for (uint256 i = 1; i < lists.length; i++) {
      registry[lists[i]] = targetStatuses[i];
    }
    return true;
  }

  modifier onlyStatus(Consts.CampaignStatus requiredStatus) {
    require(status == requiredStatus, 'Campaign: status not met');
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
