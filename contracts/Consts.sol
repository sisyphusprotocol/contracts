//SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

library Consts {
  //
  uint256 public constant DECIMAL = 10**6;
  uint256 public constant PROTOCOL_FEE = 10**5;
  uint256 public constant HOST_REWARD = 2 * 10**5;

  // tmp vitalik.eth
  address public constant PROTOCOL_RECIPIENT = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;

  enum CampaignType {
    IN_VALID,
    DAILY,
    WEEKLY
  }

  enum CampaignStatus {
    IN_VALID,
    NOT_START,
    ON_GOING,
    ENDED,
    SETTLED
  }
}
