//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import '@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import './Campaign.sol';
import 'hardhat/console.sol';
import './interface/ICampaignFactory.sol';
import './Consts.sol';

contract CampaignFactoryUpgradable is ICampaignFactory, UUPSUpgradeable, OwnableUpgradeable {
  // White list mapping
  mapping(address => bool) public whiteUsers;

  // White list token mapping, value is max amount for this token
  mapping(IERC20 => uint256) public whiteTokens;

  uint256[50] __gap;

  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

  function initialize() public initializer {
    __Ownable_init_unchained();
  }

  function modifyWhiteUser(address user, bool status) public onlyOwner {
    whiteUsers[user] = status;
    emit EvWhiteUserSet(user, status);
  }

  function modifyWhiteToken(IERC20 token, uint256 amount) public onlyOwner {
    whiteTokens[token] = amount;
    emit EvWhiteTokenSet(token, amount);
  }

  function createCampaign(
    IERC20 token,
    uint256 amount,
    string memory name,
    string memory symbol,
    uint256 startTime,
    uint256 totalPeriod,
    uint256 periodLength,
    string calldata campaignUri
  ) public override onlyWhiteUser onlyWhiteToken(token) {
    require(amount <= whiteTokens[token], 'CampaignF: amount exceed cap');
    require(block.timestamp + 600 < startTime, 'CampaignF: start too soon');
    Campaign cam = new Campaign(token, amount, name, symbol, startTime, totalPeriod, periodLength, campaignUri);

    cam.transferOwnership(msg.sender);

    emit EvCampaignCreated(msg.sender, address(cam));
  }

  modifier onlyWhiteUser() {
    require(whiteUsers[msg.sender], 'CampaignFactory: not whitelist');
    _;
  }

  modifier onlyWhiteToken(IERC20 token) {
    require(whiteTokens[token] > 0, 'CampaignFactory: not whitelist');
    _;
  }
}
