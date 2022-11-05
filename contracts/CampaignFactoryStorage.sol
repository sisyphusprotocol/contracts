//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';

import { AutomationRegistryInterface, State, Config } from '@chainlink/contracts/src/v0.8/interfaces/AutomationRegistryInterface1_2.sol';
import { LinkTokenInterface } from '@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol';

import './interface/ICampaign.sol';

contract CampaignFactoryStorage {
  // White list mapping
  mapping(address => bool) public whiteUsers;

  // White list token mapping, value is max amount for this token
  mapping(IERC20Upgradeable => uint256) public whiteTokens;

  ICampaign public i_campaign;

  // variable about chainLink
  LinkTokenInterface public i_link;
  address public registrar;
  AutomationRegistryInterface public i_registry;

  struct UpKeepInfo {
    uint256 upKeepId;
  }

  // campaign address => upkeepID
  mapping(address => UpKeepInfo) public keepUpRecords;

  address[] public OnGoingCampaigns;

  uint256[45] __gap;
}
