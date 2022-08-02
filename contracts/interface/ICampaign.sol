//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

interface ICampaign {
  function register() external;

  event EvRegisterRequest(address user);
  event EvRegisterSuccessfully(address user);
}
