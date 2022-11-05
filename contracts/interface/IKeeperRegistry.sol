//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

interface IKeeperRegistry {
  function cancelUpkeep(uint256 id) external;

  function withdrawFunds(uint256 id, address to) external;

  function getUpkeep(uint256 id)
    external
    view
    returns (
      address target,
      uint32 executeGas,
      bytes memory checkData,
      uint96 balance,
      address lastKeeper,
      address admin,
      uint64 maxValidBlocknumber,
      uint96 amountSpent
    );
}
