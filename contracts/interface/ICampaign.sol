//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

interface ICampaign {
  function signUp() external;

  function claim() external;

  function checkIn(bytes32) external;

  function admit(address[] calldata) external;

  event EvSignUp(address user);

  event EvRegisterSuccessfully(address user);

  event EvCheckIn(uint256 epoch, address user, bytes32 contentUri);

  event EvModifyRegistry(address[] users, bool[] status);

  event EvClaimReward(address, uint256);
  // who fail
  event EvFailure(address);
}
