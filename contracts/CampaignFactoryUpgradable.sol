//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import '@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';
import '@openzeppelin/contracts/proxy/Clones.sol';
import '@openzeppelin/contracts/utils/Strings.sol';

import { AutomationRegistryInterface, State, Config } from '@chainlink/contracts/src/v0.8/interfaces/AutomationRegistryInterface1_2.sol';
import { LinkTokenInterface } from '@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol';

import { Campaign } from './Campaign.sol';
import './CampaignFactoryStorage.sol';
import './interface/ICampaignFactory.sol';
import './Consts.sol';

contract CampaignFactoryUpgradable is CampaignFactoryStorage, ICampaignFactory, UUPSUpgradeable, OwnableUpgradeable {
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

    bytes32 salt = keccak256(
      abi.encodePacked(Consts.SALT, msg.sender, token, amount, name, symbol, startTime, totalPeriod, periodLength, campaignUri)
    );

    campaign = Clones.cloneDeterministic(address(i_campaign), salt);

    ICampaign(campaign).initialize(msg.sender, token, amount, name, symbol, startTime, totalPeriod, periodLength, campaignUri);

    // register chainLink keepUp
    _registerAndPredictID(
      string.concat('Sisyphus ', (Strings.toHexString(uint160(campaign), 20))),
      zero,
      address(campaign),
      Consts.UPKEEP_GAS_LIMIT,
      Consts.UPKEEP_ADMIN,
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
      // uint256 upkeepID =
      uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), address(i_registry), uint32(oldNonce))));
      // DEV - Use the upkeepID however you see fit
    } else {
      // revert('auto-approve disabled');
    }
  }

  //  delete white list in development
  // modifier onlyWhiteUser() {
  //   // require(whiteUsers[msg.sender], 'CampaignFactory: not whitelist');
  //   _;
  // }
}
