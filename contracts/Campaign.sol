//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.15;

import '@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import '@openzeppelin/contracts/utils/Base64.sol';
import '@chainlink/contracts/src/v0.8/AutomationCompatible.sol';

import './interface/ICampaign.sol';
import './interface/IRenderer.sol';

import { Consts } from './Consts.sol';
import { CampaignBase } from './CampaignBase.sol';

/// @dev for implementation of erc1167 implementation
contract Campaign is CampaignBase {
  // implementation cannot be initialize
  constructor(IRenderer render_) CampaignBase(render_) initializer {}
}
