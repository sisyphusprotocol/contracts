//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.15;

import { ICampaign } from './ICampaign.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';

interface ICampaignFactory {
  function createCampaign(
    IERC20Upgradeable token,
    uint256 amount,
    string memory name,
    string memory symbol,
    uint256 startTime,
    uint256 totalPeriod,
    uint256 periodLength,
    uint256 challengeLength,
    string calldata campaignUri,
    bytes calldata zero
  ) external returns (address campaign);

  event EvCampaignUpdated(ICampaign newImplementation);
  event EvCampaignCreated(address indexed host, address indexed campaignAddress);
  event EvWhiteUserSet(address indexed user, bool status);
  event EvWhiteTokenSet(IERC20Upgradeable indexed token, uint256 maxAmount);
  event CampaignUpKeepRegistered(address campaign, uint256 upkeepID);
  event CampaignUpKeepCancelled(address campaign);
  event CampaignUpKeepWithdrawal(address campaign);
}
