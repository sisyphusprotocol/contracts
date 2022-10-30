//SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import './interface/ICampaign.sol';
import '@chainlink/contracts/src/v0.8/AutomationCompatible.sol';

import './interface/ICampaign.sol';

import { Consts } from './Consts.sol';

// TODO: merkle tree root to valid user, don't use enumerable
contract Campaign is ICampaign, Ownable, ERC721, AutomationCompatible {
  using SafeERC20 for IERC20;

  IERC20 public immutable targetToken;
  uint256 public immutable requiredAmount;
  Consts.CampaignStatus public status;

  string public campaignUri;
  uint256 public immutable startTime;
  uint256 public immutable totalEpochsCount;
  uint256 public immutable period;

  uint256 public lastEpochEndTime;
  uint256 public currentEpoch;

  uint256 public _idx;
  uint256 public _challengeIdx;
  uint256 public challengeJudgedCount;
  uint256 public cheatCount;

  uint256 public sharedReward;
  uint256 public hostReward;
  uint256 public protocolFee;
  uint256 public successTokensCount;

  // epoch => tokenId => Record
  mapping(uint256 => mapping(uint256 => Record)) public records;

  // tokenId => token status
  mapping(uint256 => TokenProperty) public properties;

  //challengeRecordId => tokenId => voter
  mapping(uint256 => mapping(uint256 => Voter)) public voters;

  //challengeRecordId => ChallengeRecord
  mapping(uint256 => ChallengeRecord) public challengeRecords;

  //for voted: true = voted; false = not voted;
  //for choice: true = think cheat; false = think not cheat;
  struct Voter {
    bool voted;
    bool choice;
  }

  //for result: true = cheat; false = not cheat;
  //for state: true = over; false = working;
  //for legal: true = over 2/3; false = not enough voter;
  struct ChallengeRecord {
    uint256 challengerId;
    uint256 cheaterId;
    uint256 agreeCount;
    uint256 disagreeCount;
    uint256 challengeRiseTime;
    bool result;
    bool state;
    bool legal;
  }

  struct TokenProperty {
    TokenStatus tokenStatus;
    uint256 pendingReward;
  }

  enum TokenStatus {
    INVALID,
    EXIT,
    SIGNED,
    ADMITTED,
    ACHIEVED,
    FAILED,
    REKT
  }

  struct Record {
    string contentUri;
  }

  constructor(
    IERC20 token_,
    uint256 amount_,
    string memory name_,
    string memory symbol_,
    uint256 startTime_,
    uint256 totalPeriod_,
    uint256 periodLength_,
    string memory campaignUri_
  ) ERC721(name_, symbol_) {
    require(address(token_) != address(0), 'Campaign: invalid token');
    require(amount_ != 0, 'Campaign: invalid amount');
    targetToken = token_;
    requiredAmount = amount_;
    startTime = startTime_;
    lastEpochEndTime = startTime_;
    totalEpochsCount = totalPeriod_;
    period = periodLength_;
    campaignUri = campaignUri_;
  }

  function setCampaignUri(string calldata newUri) external override onlyOwner {
    campaignUri = newUri;
    emit EvCampaignUriSet(campaignUri);
  }

  //
  /**
   * @dev user stake token and want to participate this campaign
   */
  function signUp() external override onlyNotStarted {
    require(balanceOf(msg.sender) == 0, 'Campaign: already signed');

    IERC20(targetToken).safeTransferFrom(msg.sender, address(this), requiredAmount);

    uint256 tokenId = _idx;
    _idx += 1;

    _safeMint(msg.sender, tokenId);

    properties[tokenId].tokenStatus = TokenStatus.SIGNED;
    properties[tokenId].pendingReward = requiredAmount;

    emit EvSignUp(tokenId);
  }

  /**
   * @dev campaign owner admit several address to participate this campaign
   * @param allowlists allowed tokenId array
   */
  function admit(uint256[] calldata allowlists) external onlyNotStarted onlyOwner {
    for (uint256 i = 0; i < allowlists.length; i++) {
      uint256 tokenId = allowlists[i];

      TokenProperty memory property = properties[tokenId];

      require(property.pendingReward == requiredAmount, 'Campaign: stake not match');
      require(property.tokenStatus == TokenStatus.SIGNED, 'Campaign: not signed up');

      properties[tokenId].tokenStatus = TokenStatus.ADMITTED;

      emit EvRegisterSuccessfully(tokenId);
    }
  }

  /**
   * @dev once campaign owner admit some address by mistake
   * @dev can modify via this function but more gas-expensive
   * @param lists modified tokenId list array
   * @param targetStatuses corresponding status array
   */
  function modifyRegistry(uint256[] calldata lists, bool[] calldata targetStatuses) external onlyNotStarted onlyOwner {
    for (uint256 i = 1; i < lists.length; i++) {
      uint256 tokenId = lists[i];
      bool targetStatus = targetStatuses[i];
      if (targetStatus) {
        // require(properties[tokenId].tokenStatus == TokenStatus.SIGNED, 'Campaign: not signed');
        properties[tokenId].tokenStatus = TokenStatus.ADMITTED;
      } else {
        // require(properties[tokenId].tokenStatus == TokenStatus.ADMITTED, 'Campaign: not admitted');
        properties[tokenId].tokenStatus = TokenStatus.SIGNED;
      }
    }
    emit EvModifyRegistry(lists, targetStatuses);
  }

  /**
   * @dev user check in
   * @param contentUri string of ipfs uri or other decentralize storage
   */
  function checkIn(string calldata contentUri, uint256 tokenId)
    external
    override
    onlyTokenHolder(tokenId)
    onlyStarted
    onlyAdmitted(tokenId)
  {
    _checkEpoch();
    records[currentEpoch][tokenId] = Record(contentUri);

    emit EvCheckIn(currentEpoch, tokenId, contentUri);
  }

  function challenge(uint256 challengerId, uint256 cheaterId)
    external
    override
    onlyTokenHolder(challengerId)
    onlyStarted
    onlyAdmitted(challengerId)
    onlyAdmitted(cheaterId)
    onlyChallengeAllowed
  {
    uint256 challengeRecordId = _challengeIdx;
    _challengeIdx += 1;

    challengeRecords[challengeRecordId].challengerId = challengerId;
    challengeRecords[challengeRecordId].cheaterId = cheaterId;
    challengeRecords[challengeRecordId].challengeRiseTime = block.timestamp;
    challengeRecords[challengeRecordId].state = true;

    emit EvChallenge(challengerId, cheaterId, challengeRecordId);
  }

  function vote(
    uint256 tokenId,
    uint256 challengeRecordId,
    bool choice
  )
    external
    override
    onlyTokenHolder(tokenId)
    onlyStarted
    onlyAdmitted(tokenId)
    onlyChallengeExist(challengeRecordId)
    onlyChallengeNotEnded(challengeRecordId)
  {
    voters[challengeRecordId][tokenId].voted = true;
    voters[challengeRecordId][tokenId].choice = choice;

    if (choice == true) {
      challengeRecords[challengeRecordId].agreeCount += 1;
    } else {
      challengeRecords[challengeRecordId].disagreeCount += 1;
    }

    emit EvVote(tokenId, challengeRecordId);
  }

  function judgement(uint256 challengeRecordId)
    external
    override
    onlyChallengeEnded(challengeRecordId)
    onlyChallengeExist(challengeRecordId)
    onlyNotJudged(challengeRecordId)
  {
    uint256 _challengerId = challengeRecords[challengeRecordId].challengerId;
    uint256 _cheaterId = challengeRecords[challengeRecordId].cheaterId;
    uint256 _count = challengeRecords[challengeRecordId].agreeCount + challengeRecords[challengeRecordId].disagreeCount;

    require(_count >= (_idx * Consts.legalVoterRatio) / Consts.SCALE, 'Challenge: not enough voter');

    challengeJudgedCount += 1;

    bool _result = (challengeRecords[challengeRecordId].agreeCount > challengeRecords[challengeRecordId].disagreeCount);
    challengeRecords[challengeRecordId].result = _result;
    challengeRecords[challengeRecordId].state = true;

    if (_result) {
      properties[_cheaterId].tokenStatus = TokenStatus.FAILED;

      uint256 _tranReward = properties[_cheaterId].pendingReward;
      properties[_cheaterId].pendingReward = 0;
      properties[challengeRecords[challengeRecordId].challengerId].pendingReward +=
        (_tranReward * Consts.challengerSuccessRatio) /
        Consts.SCALE;
      sharedReward += (_tranReward * Consts.successSharedRatio) / Consts.SCALE;
      protocolFee += (_tranReward * Consts.successProtocolRatio) / Consts.SCALE;

      cheatCount += 1;

      emit EvFailure(_cheaterId);
      emit EvCheat(_cheaterId);
    } else {
      uint256 _tranReward = ((properties[_challengerId].pendingReward) * Consts.challengerFailRatio) / Consts.SCALE;
      properties[challengeRecords[challengeRecordId].challengerId].pendingReward =
        ((properties[challengeRecords[challengeRecordId].challengerId].pendingReward) *
          (Consts.SCALE - Consts.challengerFailRatio)) /
        Consts.SCALE;
      sharedReward += (_tranReward * Consts.failSharedRatio) / Consts.SCALE;
      protocolFee += (_tranReward * Consts.failProtocolRatio) / Consts.SCALE;
    }

    emit EvJudgement(challengeRecordId);
  }

  function forceEnd() external onlyEnoughCheater onlyAllJudged {
    _forceSettle();
  }

  /**
   * @dev everyone can call the function to settle reward
   */
  function settle() external override {
    _settle();
  }

  /**
   * @dev user claim reward after campaign settled
   */
  function claim(uint256 tokenId) external override onlyTokenHolder(tokenId) onlyAllJudged {
    _claim(tokenId);
  }

  /**
   * @dev host who participate the campaign claim reward and withdraw host reward
   */
  function claimAndWithdraw(uint256 tokenId) external override onlyOwner onlyTokenHolder(tokenId) onlyAllJudged {
    _claim(tokenId);
    _withdraw();
  }

  /**
   * @dev host withdraw host reward
   */
  function withdraw() external override onlyOwner onlySettled {
    _withdraw();
  }

  /**
   * @dev
   */
  function checkUpkeep(
    bytes calldata /* checkData */
  )
    external
    view
    override
    returns (
      bool upkeepNeeded,
      bytes memory /* performData */
    )
  {
    upkeepNeeded = block.timestamp - lastEpochEndTime > period;
  }

  /**
   *
   */
  function performUpkeep(
    bytes calldata /* performData */
  ) external override {
    _checkEpoch();
  }

  /**
   * @dev
   */
  function _claim(uint256 tokenId) private {
    if (status != Consts.CampaignStatus.SETTLED) {
      _settle();
    }

    uint256 reward = properties[tokenId].pendingReward == 0
      ? 0
      : properties[tokenId].pendingReward + sharedReward / successTokensCount;

    IERC20(targetToken).safeTransfer(msg.sender, reward);

    properties[tokenId].pendingReward = 0;

    emit EvClaimReward(tokenId, reward);
  }

  /**
   * @dev host withdraw host reward
   */
  function _withdraw() private {
    uint256 reward = hostReward;
    hostReward = 0;

    IERC20(targetToken).safeTransfer(msg.sender, reward);

    IERC20(targetToken).safeTransfer(Consts.PROTOCOL_RECIPIENT, protocolFee);

    emit EvWithDraw(msg.sender, reward, protocolFee);
  }

  /**
   * @dev someone will call the function to settle the campaign
   */
  function _settle() private onlyEnded {
    successTokensCount = _idx;
    for (uint256 tokenId = 0; tokenId < _idx; tokenId++) {
      for (uint256 j = 0; j < totalEpochsCount; j++) {
        string memory content = records[j][tokenId].contentUri;
        if (bytes(content).length == 0) {
          uint256 penalty = properties[tokenId].pendingReward;
          hostReward += (penalty * Consts.HOST_REWARD) / Consts.DECIMAL;
          protocolFee += (penalty * Consts.PROTOCOL_FEE) / Consts.DECIMAL;
          sharedReward += penalty - hostReward - protocolFee;
          properties[tokenId].pendingReward = 0;
          successTokensCount = successTokensCount - 1;
          emit EvFailure(tokenId);
          break;
        }
      }
      emit EvSuccess(tokenId);
    }
    // If nobody success, sharedReward come to protocol
    if (successTokensCount == 0) {
      protocolFee += sharedReward;
      sharedReward = 0;
    }
    status = Consts.CampaignStatus.SETTLED;

    emit EvSettle(msg.sender);
  }

  function _forceSettle() private onlyEnoughCheater {
    successTokensCount = _idx;
    for (uint256 tokenId = 0; tokenId < _idx; tokenId++) {
      for (uint256 j = 0; j < totalEpochsCount; j++) {
        string memory content = records[j][tokenId].contentUri;
        if (bytes(content).length == 0) {
          uint256 penalty = properties[tokenId].pendingReward;
          hostReward += (penalty * Consts.HOST_REWARD) / Consts.DECIMAL;
          protocolFee += (penalty * Consts.PROTOCOL_FEE) / Consts.DECIMAL;
          sharedReward += penalty - hostReward - protocolFee;
          properties[tokenId].pendingReward = 0;
          successTokensCount = successTokensCount - 1;
          emit EvFailure(tokenId);
          break;
        }
      }
      emit EvSuccess(tokenId);
    }
    // If nobody success, sharedReward come to protocol
    if (successTokensCount == 0) {
      protocolFee += sharedReward;
      sharedReward = 0;
    }
    status = Consts.CampaignStatus.SETTLED;

    emit EvSettle(msg.sender);
  }

  function _checkEpoch() private {
    if (block.timestamp - lastEpochEndTime > period) {
      uint256 n = (block.timestamp - lastEpochEndTime) / period;
      currentEpoch += n;
      lastEpochEndTime += period * n;
    }

    require(currentEpoch < totalEpochsCount, 'Campaign: checkEpoch too late');
  }

  // Do not allow transfer
  function _beforeTokenTransfer(
    address from,
    address,
    uint256
  ) internal pure override {
    require(from == address(0), 'Campaign: Could not transfer');
  }

  function _readTokenHolder(uint256 tokenId) private view {
    require(ownerOf(tokenId) == msg.sender, 'Campaign: not token holder');
  }

  function _getAdmitted(uint256 tokenId) internal view {
    require(properties[tokenId].tokenStatus == TokenStatus.ADMITTED, 'Campaign: not admitted');
  }

  function _readChallengeExist(uint256 challengeRecordId) private view {
    require(challengeRecordId < _challengeIdx, 'ChallengeRecord: not exist');
  }

  function _checkSettled() private view {
    require(status == Consts.CampaignStatus.SETTLED, 'Campaign: not settled');
  }

  function _checkEnded() private view {
    require(block.timestamp > startTime + totalEpochsCount * period, 'Campaign: not ended');
  }

  function _checkNotStarted() private view {
    require(block.timestamp < startTime, 'Campaign: already started');
  }

  function _checkStarted() private view {
    require(block.timestamp >= startTime, 'Campaign: not start');
  }

  function _checkAllJudged() private view {
    require(_challengeIdx == challengeJudgedCount, 'Challenge: not all judged');
  }

  function _checkEnoughCheater() private view {
    require(cheatCount >= (_idx * Consts.cheaterRatio) / Consts.SCALE, 'Campaign: not enough cheater');
  }

  modifier onlyTokenHolder(uint256 tokenId) {
    _readTokenHolder(tokenId);
    _;
  }

  modifier onlySettled() {
    _checkSettled();
    _;
  }

  modifier onlyEnded() {
    _checkEnded();
    _;
  }

  modifier onlyStarted() {
    _checkStarted();
    _;
  }

  modifier onlyNotStarted() {
    _checkNotStarted();
    _;
  }

  modifier onlyAdmitted(uint256 tokenId) {
    _getAdmitted(tokenId);
    _;
  }

  modifier onlyChallengeExist(uint256 challengeRecordId) {
    _readChallengeExist(challengeRecordId);
    _;
  }

  modifier onlyChallengeNotEnded(uint256 challengeRecordId) {
    require(block.timestamp < challengeRecords[challengeRecordId].challengeRiseTime + 7 days, 'Challenge: ended');
    _;
  }

  modifier onlyChallengeEnded(uint256 challengeRecordId) {
    require(block.timestamp >= challengeRecords[challengeRecordId].challengeRiseTime + 7 days, 'Challenge: not ended');
    _;
  }

  modifier onlyChallengeAllowed() {
    require(block.timestamp <= startTime + totalEpochsCount * period + 1 days, 'Challenge: not allowed');
    _;
  }

  modifier onlyNotJudged(uint256 challengeRecordId) {
    require(challengeRecords[challengeRecordId].state == false, 'Challenge: already judged');
    _;
  }

  modifier onlyAllJudged() {
    _checkAllJudged();
    _;
  }

  modifier onlyEnoughCheater() {
    _checkEnoughCheater();
    _;
  }
}
