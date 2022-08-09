//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

interface ICampaign {
  // user sign up the campaign
  function signUp() external;

  // host allow user to participate
  function admit(address[] calldata) external;

  // user check at a fixed frequency
  function checkIn(bytes32) external;

  // user claim reward after campaign ended
  function claim() external;

  event EvSignUp(address user);

  event EvRegisterSuccessfully(address user);

  event EvCheckIn(uint256 epoch, address user, bytes32 contentUri);

  event EvModifyRegistry(address[] users, bool[] status);

  event EvClaimReward(address, uint256);
  // who fail
  event EvFailure(address);

  event EvWithDraw(address host, uint256, uint256);
}
