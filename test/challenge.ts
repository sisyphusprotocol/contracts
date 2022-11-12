import { deployments } from 'hardhat';

import { getCurrentTime, TimeGo, getContract } from './utils';
import { CampaignBase, TestERC20 } from '../typechain';
import { expect } from 'chai';

const requiredAmount = 10n * 10n ** 18n;
const dayLength = 86400;

const setupTest = deployments.createFixture(
  // eslint-disable-next-line no-unused-vars
  async ({ deployments, getNamedAccounts, ethers }, options) => {
    /**
     * host: campaign host
     * A: who possibly cheat
     * B: who challenge A
     * users: others who have power to vote
     */
    const [host, A, B, ...users] = await ethers.getSigners();
    const testErc20 = await getContract<TestERC20>('TestERC20');
    const campaign = await getContract<CampaignBase>('CampaignBase');
    await deployments.fixture(); // ensure you start from a fresh deployments

    const now = await getCurrentTime();
    // initialize the campaign with 3 days
    campaign.initialize(
      host.address,
      testErc20.address,
      requiredAmount,
      'TestCampaign',
      'TC',
      now + dayLength / 2,
      dayLength,
      30,
      'ipfs://',
    );

    const tokenIdMap: { [x: string]: string } = {};
    // mint erc20 token and signUp, then host admin
    for (const u of [A, B, ...users]) {
      await testErc20.connect(u).mint(u.address, requiredAmount);
      await testErc20.connect(u).approve(campaign.address, requiredAmount);
      const tx = await campaign.connect(u).signUp();
      const rc = await tx.wait();
      const event = rc.events?.find((event) => event.event === 'EvSignUp');
      const { tokenId } = event?.args!;
      tokenIdMap[u.address] = tokenId;
      await campaign.connect(host).admit([tokenId]);
    }

    // timeGo and campaign should start
    await TimeGo(dayLength);

    // A checkIn
    await campaign.connect(A).checkIn('ipfs://', tokenIdMap[A.address]);

    // should A cannot challenge himself
    await expect(campaign.connect(A).challenge(tokenIdMap[A.address], tokenIdMap[A.address])).to.be.revertedWith(
      'Campaign: cannot challenge self',
    );

    // should challenge on be half of the other fail
    await expect(campaign.connect(B).challenge(tokenIdMap[A.address], tokenIdMap[B.address])).to.be.revertedWith(
      'Campaign: not token holder',
    );

    // should B start challenge successfully
    await expect(campaign.connect(B).challenge(tokenIdMap[B.address], tokenIdMap[A.address]))
      .to.be.emit(campaign, 'EvChallenge')
      .withArgs(tokenIdMap[B.address], tokenIdMap[A.address], 0);

    return {
      testErc20: testErc20,
      campaign: campaign,
      host: host,
      A: A,
      B: B,
      users: users,
      tokenIdMap: tokenIdMap,
    };
  },
);

describe('CampaignChallenge', function () {
  it('Should should A, B cannot vote', async () => {
    const { campaign, A, B, tokenIdMap } = await setupTest();

    await expect(campaign.connect(A).vote(tokenIdMap[A.address], 0, true)).to.be.revertedWith(
      'Challenge: involved cannot vote',
    );
    await expect(campaign.connect(B).vote(tokenIdMap[B.address], 0, true)).to.be.revertedWith(
      'Challenge: involved cannot vote',
    );
  });

  it("Should it doesn't count if voting users is not enough", async () => {
    const { campaign, tokenIdMap, users } = await setupTest();

    const totalCount = users.length;
    const voteCount = Math.floor(totalCount * 0.66);
    // voteCount users to vote for this challenge
    for (const u of users.slice(0, voteCount)) {
      await expect(campaign.connect(u).vote(tokenIdMap[u.address], 0, true))
        .to.be.emit(campaign, 'EvVote')
        .withArgs(tokenIdMap[u.address], 0);
    }

    // time pass and the challenge can be judged
    await TimeGo(86400 * 8);

    await expect(campaign.judgement(0)).to.be.revertedWith('Challenge: not enough voter');
  });

  it('Should B challenge successfully work properly', async () => {
    const { campaign, tokenIdMap, users, A, B } = await setupTest();

    const totalCount = users.length;
    const agreeCount = Math.floor(totalCount * 0.66);

    // agreeCount users to vote agree for this challenge
    for (const u of users.slice(0, agreeCount)) {
      await expect(campaign.connect(u).vote(tokenIdMap[u.address], 0, true))
        .to.be.emit(campaign, 'EvVote')
        .withArgs(tokenIdMap[u.address], 0);
    }

    // other users to vote disagree for this challenge
    for (const u of users.slice(agreeCount, totalCount)) {
      await expect(campaign.connect(u).vote(tokenIdMap[u.address], 0, false))
        .to.be.emit(campaign, 'EvVote')
        .withArgs(tokenIdMap[u.address], 0);
    }

    // time pass and the challenge can be judged
    await TimeGo(86400 * 8);

    // make judgement to the challenge
    await expect(campaign.judgement(0))
      .to.be.emit(campaign, 'EvFailure')
      .withArgs(tokenIdMap[A.address])
      .emit(campaign, 'EvCheat')
      .withArgs(tokenIdMap[A.address])
      .emit(campaign, 'EvJudgement')
      .withArgs(0);

    // check value
    expect((await campaign.getTokenProperties(tokenIdMap[A.address])).pendingReward).to.be.equal(0);
    /// 60% of a to b
    expect((await campaign.getTokenProperties(tokenIdMap[B.address])).pendingReward).to.be.equal(
      (requiredAmount * 160n) / 100n,
    );
    /// 30% of a to share reward pool
    expect(await campaign.sharedReward()).to.be.equal((requiredAmount * 30n) / 100n);
    /// 10% of a to protocol
    expect(await campaign.protocolFee()).to.be.equal((requiredAmount * 10n) / 100n);

    // could not judge again
    await expect(campaign.judgement(0)).to.be.revertedWith('Challenge: already judged');
  });

  it('Should B challenge fail work properly', async () => {
    const { campaign, tokenIdMap, users, A } = await setupTest();

    const totalCount = users.length;
    const agreeCount = Math.floor(totalCount * 0.33);

    // agreeCount users to vote agree for this challenge
    for (const u of users.slice(0, agreeCount)) {
      await expect(campaign.connect(u).vote(tokenIdMap[u.address], 0, true))
        .to.be.emit(campaign, 'EvVote')
        .withArgs(tokenIdMap[u.address], 0);
    }

    // other users to vote disagree for this challenge
    for (const u of users.slice(agreeCount, totalCount)) {
      await expect(campaign.connect(u).vote(tokenIdMap[u.address], 0, false))
        .to.be.emit(campaign, 'EvVote')
        .withArgs(tokenIdMap[u.address], 0);
    }

    // time pass and the challenge can be judged
    await TimeGo(86400 * 8);

    // make judgement to the challenge
    await expect(campaign.judgement(0)).to.be.emit(campaign, 'EvJudgement').withArgs(0);

    // check value
    // a value doesn't change
    expect((await campaign.getTokenProperties(tokenIdMap[A.address])).pendingReward).to.be.equal(requiredAmount);
    /// 30% of b to share reward pool
    expect(await campaign.sharedReward()).to.be.equal((requiredAmount * 30n) / 100n);
    /// 10% of b to protocol
    expect(await campaign.protocolFee()).to.be.equal((requiredAmount * 10n) / 100n);

    // could not judge again
    await expect(campaign.judgement(0)).to.be.revertedWith('Challenge: already judged');
  });
});
