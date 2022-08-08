//SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

library Consts {
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
