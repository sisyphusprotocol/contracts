//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.15;

interface KeeperRegistrarInterface {
  function register(
    string memory name,
    bytes calldata encryptedEmail,
    address upkeepContract,
    uint32 gasLimit,
    address adminAddress,
    bytes calldata checkData,
    uint96 amount,
    uint8 source,
    address sender
  ) external;
}

library Consts {
  //
  uint256 public constant DECIMAL = 10**6;
  uint256 public constant PROTOCOL_FEE = 10**5;
  uint256 public constant HOST_REWARD = 2 * 10**5;

  /// @dev challenge related constant, in percent
  /// @dev minimal required vote ratio for a valid challenge judgement
  uint8 public constant legalVoterRatio = 66;
  /// @dev the campaign exit if enough people are challenged as cheater
  uint8 public constant cheaterRatio = 30;
  /// @dev if challenge success, how many shared to challenger
  uint8 public constant challengerSuccessRatio = 60;
  /// @dev if challenge success, how many shared to voter
  uint8 public constant successSharedRatio = 30;
  /// @dev if challenge success, how many shared to protocol
  uint8 public constant successProtocolRatio = 10;
  /// @dev if challenge fail, how many decrease
  uint8 public constant challengerFailRatio = 40;
  /// @dev if challenge fail, how many shared to voter
  uint8 public constant failSharedRatio = 75;
  /// @dev if challenge success, how many shared to protocol
  uint8 public constant failProtocolRatio = 25;
  uint8 public constant SCALE = 100;

  bytes32 public constant SALT = keccak256(abi.encode('Sisyphus Protocol'));

  // tmp vitalik.eth
  address public constant PROTOCOL_RECIPIENT = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
  address public constant UPKEEP_ADMIN = 0x11F2241Bf12f1a640f78e5d1A0d3302D77fB5e78;

  // chainlink
  bytes4 public constant registerSig = KeeperRegistrarInterface.register.selector;
  // LinkSend
  uint96 public constant MIN_LINK_AMOUNT = 5000000000000000000;
  // upKeep GasLimit
  uint32 public constant UPKEEP_GAS_LIMIT = 5000000;

  // upKeep Cancel Delay same as the number in KeeperRegistry
  uint256 public constant CANCELATION_DELAY = 50;

  uint64 public constant UINT64_MAX = 2**64 - 1;

  enum CampaignType {
    IN_VALID,
    DAILY,
    WEEKLY
  }

  enum CampaignStatus {
    IN_VALID,
    NOT_START,
    ON_GOING,
    ENDED,
    SETTLED
  }
}
