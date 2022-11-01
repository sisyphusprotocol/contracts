//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

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
    string calldata campaignUri,
    bytes calldata zero
  ) external returns (address campaign);

  event EvCampaignCreated(address indexed host, address indexed campaignAddress);
  event EvWhiteUserSet(address indexed user, bool status);
  event EvWhiteTokenSet(IERC20Upgradeable indexed token, uint256 maxAmount);
}
