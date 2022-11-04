//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

interface IKeeperRegistry {
  function cancelUpkeep(uint256 id) external;

  function withdrawFunds(uint256 id, address to) external;
}
