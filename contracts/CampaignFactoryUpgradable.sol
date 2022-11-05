//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import '@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';
import '@openzeppelin/contracts/proxy/Clones.sol';
import '@openzeppelin/contracts/utils/Strings.sol';

import { AutomationRegistryInterface, State, Config } from '@chainlink/contracts/src/v0.8/interfaces/AutomationRegistryInterface1_2.sol';
import { LinkTokenInterface } from '@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol';
import '@chainlink/contracts/src/v0.8/AutomationCompatible.sol';
import './interface/IKeeperRegistry.sol';

import { Campaign } from './Campaign.sol';
import './CampaignFactoryStorage.sol';
import './interface/ICampaignFactory.sol';
import './Consts.sol';

contract CampaignFactoryUpgradable is
  CampaignFactoryStorage,
  ICampaignFactory,
  UUPSUpgradeable,
  OwnableUpgradeable,
  AutomationCompatible
{
  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

  function initialize(
    ICampaign campaign_,
    LinkTokenInterface link_,
    address registrar_,
    AutomationRegistryInterface registry_
  ) public initializer {
    i_campaign = campaign_;
    i_link = link_;
    registrar = registrar_;
    i_registry = registry_;
    __Ownable_init_unchained();
  }

  function modifyWhiteToken(IERC20Upgradeable token, uint256 amount) external onlyOwner {
    whiteTokens[token] = amount;
    emit EvWhiteTokenSet(token, amount);
  }

  function updateCampaignImplementation(ICampaign newImplementation) external onlyOwner {
    i_campaign = newImplementation;
    emit EvCampaignUpdated(newImplementation);
  }

  function createCampaign(
    IERC20Upgradeable token,
    uint256 amount,
    string memory name,
    string memory symbol,
    uint256 startTime,
    uint256 totalPeriod,
    uint256 periodLength,
    string calldata campaignUri,
    // please set to 0x
    bytes calldata zero
  ) public override returns (address campaign) {
    require(amount <= whiteTokens[token], 'CampaignF: amount exceed cap');
    require(block.timestamp < startTime, 'CampaignF: start too soon');
    require(i_link.balanceOf(address(this)) >= uint256(Consts.MIN_LINK_AMOUNT), 'CampaignF: not enough $Link');

    campaign = Clones.cloneDeterministic(
      address(i_campaign),
      keccak256(
        abi.encodePacked(
          Consts.SALT,
          msg.sender,
          token,
          amount,
          name,
          symbol,
          startTime,
          totalPeriod,
          periodLength,
          campaignUri
        )
      )
    );

    ICampaign(campaign).initialize(msg.sender, token, amount, name, symbol, startTime, totalPeriod, periodLength, campaignUri);

    // register chainLink keepUp
    _registerAndPredictID(
      string.concat('Sisyphus ', (Strings.toHexString(uint160(campaign), 20))),
      zero,
      address(campaign),
      Consts.UPKEEP_GAS_LIMIT,
      address(this),
      zero,
      Consts.MIN_LINK_AMOUNT,
      0
    );

    emit EvCampaignCreated(msg.sender, address(campaign));
  }

  function _registerAndPredictID(
    string memory name,
    bytes calldata encryptedEmail,
    address upkeepContract,
    uint32 gasLimit,
    address adminAddress,
    bytes calldata checkData,
    uint96 amount,
    uint8 source
  ) internal {
    (State memory state, Config memory _c, address[] memory _k) = i_registry.getState();
    uint256 oldNonce = state.nonce;
    bytes memory payload = abi.encode(
      name,
      encryptedEmail,
      upkeepContract,
      gasLimit,
      adminAddress,
      checkData,
      amount,
      source,
      address(this)
    );

    i_link.transferAndCall(registrar, amount, bytes.concat(Consts.registerSig, payload));

    (state, _c, _k) = i_registry.getState();
    uint256 newNonce = state.nonce;
    if (newNonce == oldNonce + 1) {
      uint256 upkeepID = uint256(
        keccak256(abi.encodePacked(blockhash(block.number - 1), address(i_registry), uint32(oldNonce)))
      );
      _saveUpKeep(upkeepContract, upkeepID);
    } else {
      revert('auto-approve disabled');
    }
  }

  /**
   * @dev check Upkeep
   */
  function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory performData) {
    // travel the OnGoingCampaigns
    for (uint256 i = 0; i < OnGoingCampaigns.length; i++) {
      ICampaign campaign = ICampaign(OnGoingCampaigns[i]);
      (
        address _t,
        uint32 _e,
        bytes memory _c,
        uint96 balance,
        address _l,
        address _a,
        uint64 maxValid,
        uint96 _as
      ) = IKeeperRegistry(address(i_registry)).getUpkeep(keepUpRecords[address(campaign)].upKeepId);

      // check whether it's time to cancel
      bool canceled = maxValid != Consts.UINT64_MAX;
      if (campaign.status() == Consts.CampaignStatus.SETTLED && !canceled) {
        upkeepNeeded = true;
        performData = abi.encode(address(campaign), uint256(0));
        return (upkeepNeeded, performData);
      }

      // check whether it's time to withdraw after cancel
      if (block.number > maxValid + Consts.CANCELATION_DELAY && balance != uint96(0)) {
        upkeepNeeded = true;
        performData = abi.encode(address(campaign), uint256(1));
        return (upkeepNeeded, performData);
      }
    }
  }

  /**
   * @dev two kind of perform
   * 0: cancel upKeep of campaign
   * 1: withdraw upKeep $link
   */
  function performUpkeep(bytes calldata performData) external override {
    (address campaign, uint256 kind) = abi.decode(performData, (address, uint256));

    if (kind == 0) {
      // cancel keep up
      AutomationRegistryInterface(i_registry).cancelUpkeep(keepUpRecords[campaign].upKeepId);

      emit CampaignUpKeepCancelled(campaign);
    } else if (kind == 1) {
      // withdraw fund
      IKeeperRegistry(address(i_registry)).withdrawFunds(keepUpRecords[campaign].upKeepId, address(this));
      emit CampaignUpKeepWithdrawal(campaign);
    }
  }

  /**
   * @dev use in development
   */

  function cancelUpKeep(address campaign) external onlyOwner {
    AutomationRegistryInterface(i_registry).cancelUpkeep(keepUpRecords[campaign].upKeepId);
  }

  /**
   * @dev use in development
   */
  function withdrawUpKeep(address campaign) external onlyOwner {
    IKeeperRegistry(address(i_registry)).withdrawFunds(keepUpRecords[campaign].upKeepId, msg.sender);
  }

  /**
   * @dev use in development, manually edit data
   */
  function setKeepUpRecords(address campaign, UpKeepInfo calldata upKeepInfo) external onlyOwner {
    keepUpRecords[campaign] = upKeepInfo;
  }

  /**
   * @dev save upKeepId mapping, avoid stack too deep
   */
  function _saveUpKeep(address upkeepContract, uint256 upkeepID) private {
    // record up keep mapping
    keepUpRecords[upkeepContract].upKeepId = upkeepID;
    // just push, it doesn't matter too much not to pop.
    OnGoingCampaigns.push(upkeepContract);

    emit CampaignUpKeepRegistered(upkeepContract, upkeepID);
  }

  /**
   * @dev compatible with hardhat deploy, maybe removed later
   */
  function saveOwnerInAdmin() external {
    address o = owner();
    assembly {
      sstore(_ADMIN_SLOT, o)
    }
  }
}
