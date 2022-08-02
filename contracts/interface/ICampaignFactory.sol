//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '../Consts.sol';

interface ICampaignFactory {
  function createCampaign(
    Consts.CampaignType t,
    IERC20 token,
    uint256 amount,
    string memory name,
    string memory symbol
  ) external returns (bool success);

  event EvCampaignCreated(address indexed promoter, address indexed campaignAddress);
  event EvWhiteUserSet(address indexed user, bool status);
  event EvWhiteTokenSet(IERC20 indexed token, uint256 maxAmount);
}
