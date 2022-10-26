//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import { AutomationRegistryInterface, State, Config } from '@chainlink/contracts/src/v0.8/interfaces/AutomationRegistryInterface1_2.sol';
import { LinkTokenInterface } from '@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol';

// import 'hardhat/console.sol';

contract CampaignFactoryStorage {
  // White list mapping
  mapping(address => bool) public whiteUsers;

  // White list token mapping, value is max amount for this token
  mapping(IERC20 => uint256) public whiteTokens;

  // variable about chainLink
  LinkTokenInterface public i_link;
  address public registrar;
  AutomationRegistryInterface public i_registry;

  uint256[47] __gap;
}
