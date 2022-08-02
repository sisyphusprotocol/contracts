//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract TestERC20 is ERC20 {
  constructor(
    string memory name,
    string memory symbol,
    uint256 totalSupply
  ) ERC20(name, symbol) {
    _mint(msg.sender, totalSupply);
  }

  function mint(address account, uint256 amount) external returns (bool) {
    _mint(account, amount);
    return true;
  }
}
