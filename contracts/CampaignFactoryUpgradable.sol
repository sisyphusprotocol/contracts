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
import { AutomationRegistryInterface, State, Config } from '@chainlink/contracts/src/v0.8/interfaces/AutomationRegistryInterface1_2.sol';

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
   * @dev two kind of check
   * 0: whether the campaign is ended and cancel the upKeep
   * 1: whether it is the time to withdraw $link reserved
   */
  function checkUpkeep(bytes calldata checkData) external view override returns (bool upkeepNeeded, bytes memory performData) {
    uint256 kind = abi.decode(checkData, (uint256));

    if (kind == 0) {
      // check ended campaign and try to cancel upKeep
      for (uint256 i = 0; i < OnGoingCampaigns.length; i++) {
        ICampaign campaign = ICampaign(OnGoingCampaigns[i]);
        if (campaign.status() == Consts.CampaignStatus.ENDED && !keepUpRecords[address(campaign)].cancelled) {
          upkeepNeeded = true;
          performData = abi.encode(address(this), kind);
        }
      }
    } else if (kind == 1) {
      // check whether it's time to cancel upKeep
      for (uint256 i = 0; i < OnGoingCampaigns.length; i++) {
        address campaign = OnGoingCampaigns[i];
        if (
          keepUpRecords[campaign].withdrawalBlockNumber != 0 && block.number > keepUpRecords[campaign].withdrawalBlockNumber
        ) {
          upkeepNeeded = true;
          performData = abi.encode(address(this), kind);
        }
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
      keepUpRecords[campaign].cancelled = true;

      emit CampaignUpKeepCancelled(campaign);
    } else if (kind == 1) {
      // withdraw fund
      IKeeperRegistry(address(i_registry)).withdrawFunds(keepUpRecords[campaign].upKeepId, address(this));
      emit CampaignUpKeepWithdrawal(campaign);
    }
  }

  function cancelUpKeep(address campaign) external onlyOwner {
    AutomationRegistryInterface(i_registry).cancelUpkeep(keepUpRecords[campaign].upKeepId);
  }

  function withdrawUpKeep(address campaign) external onlyOwner {
    IKeeperRegistry(address(i_registry)).withdrawFunds(keepUpRecords[campaign].upKeepId, msg.sender);
  }

  /**
   * @dev save upKeepId mapping, avoid stack too deep
   */
  function _saveUpKeep(address upkeepContract, uint256 upkeepID) private {
    // record up keep mapping
    keepUpRecords[upkeepContract].upKeepId = upkeepID;

    OnGoingCampaigns.push(upkeepContract);

    emit CampaignUpKeepRegistered(upkeepContract, upkeepID);
  }
}
