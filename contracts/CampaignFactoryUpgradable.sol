//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import '@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import './Campaign.sol';

import 'hardhat/console.sol';
import './interface/ICampaignFactory.sol';

contract CampaignFactoryUpgradable is ICampaignFactory, UUPSUpgradeable, OwnableUpgradeable {
  // White list mapping
  mapping(address => bool) public whiteUsers;

  // White list token mapping
  mapping(IERC20 => bool) public whiteTokens;

  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

  function initialize() public initializer {
    __Ownable_init_unchained();
  }

  function modifyWhiteUser(address user, bool status) public onlyOwner {
    whiteUsers[user] = status;
    emit EvWhiteUserSet(user, status);
  }

  function modifyWhiteToken(IERC20 token, bool status) public onlyOwner {
    whiteTokens[token] = status;
    emit EvWhiteTokenSet(token, status);
  }

  function createCampaign(
    IERC20 token,
    uint256 amount,
    string memory name,
    string memory symbol
  ) public override onlyWhiteUser onlyWhiteToken(token) returns (bool) {
    Campaign cam = new Campaign(token, amount, name, symbol);
    emit EvCampaignCreated(msg.sender, address(cam));
    return true;
  }

  modifier onlyWhiteUser() {
    require(whiteUsers[msg.sender], 'CampaignFactory: not whitelist');
    _;
  }

  modifier onlyWhiteToken(IERC20 token) {
    require(whiteTokens[token], 'CampaignFactory: not whitelist');
    _;
  }
}
