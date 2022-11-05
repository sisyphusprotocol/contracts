//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';
import { Consts } from '../Consts.sol';

interface ICampaign {
  function initialize(
    address owner,
    IERC20Upgradeable token_,
    uint256 amount_,
    string memory name_,
    string memory symbol_,
    uint256 startTime_,
    uint256 totalPeriod_,
    uint256 periodLength_,
    string memory campaignUri_
  ) external;

  function status() external view returns (Consts.CampaignStatus);

  // owner update content uri
  function setCampaignUri(string calldata newUri) external;

  // user sign up the campaign
  function signUp() external;

  // host allow user to participate
  function admit(uint256[] calldata) external;

  // user check at a fixed frequency
  function checkIn(string calldata, uint256) external;

  // settle the reward
  function settle() external;

  // user claim reward after campaign ended
  function claim(uint256 tokenId) external;

  function claimAndWithdraw(uint256 tokenId) external;

  function withdraw() external;

  function challenge(uint256, uint256) external;

  function vote(
    uint256,
    uint256,
    bool
  ) external;

  function judgement(uint256) external;

  function forceEnd() external;

  // epoch update event;
  event EpochUpdated(uint256 currentEpoch);

  event EvCampaignUriSet(string newUri);

  event EvSignUp(uint256 tokenId);

  event EvRegisterSuccessfully(uint256 tokenId);

  event EvCheckIn(uint256 epoch, uint256 tokenId, string contentUri);

  event EvModifyRegistry(uint256[] tokenList, bool[] status);

  // settle the campaign event
  event EvSettle(address user);

  event EvClaimReward(uint256 tokenId, uint256 amount);
  // who fail
  event EvFailure(uint256 tokenId);
  // who success
  event EvSuccess(uint256 tokenId);

  event EvWithDraw(address host, uint256 hostReward, uint256 protocolFee);

  event EvChallenge(uint256 challengerId, uint256 cheaterId, uint256 challengeRecordId);

  event EvVote(uint256 tokenId, uint256 challengeRecordId);

  event EvJudgement(uint256 challengeRecordId);

  event EvCheat(uint256 cheaterId);
}
