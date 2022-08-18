//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

interface ICampaign {
  // user sign up the campaign
  function signUp() external;

  // host allow user to participate
  function admit(uint256[] calldata) external;

  // user check at a fixed frequency
  function checkIn(bytes32, uint256) external;

  // settle the reward
  function settle() external;

  // user claim reward after campaign ended
  function claim(uint256 tokenId) external;

  event EvSignUp(uint256 tokenId);

  event EvRegisterSuccessfully(uint256 tokenId);

  event EvCheckIn(uint256 epoch, uint256 tokenId, bytes32 contentUri);

  event EvModifyRegistry(uint256[] tokenList, bool[] status);

  event EvClaimReward(address, uint256);
  // who fail
  event EvFailure(uint256);

  event EvWithDraw(address host, uint256, uint256);
}
