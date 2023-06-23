// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TKFToken is ERC20 {
  uint256 public constant TOKENS_PER_ETH = 1000;
  address public owner;

  constructor() ERC20("Taskify Token", "TKF") {
    owner = msg.sender;
  }

  function buyTokens() external payable {
    uint256 tokenAmount = msg.value * TOKENS_PER_ETH;
    _mint(msg.sender, tokenAmount);
  }

  function sellTokens(uint256 tokenAmount) external {
    uint256 ethAmount = tokenAmount / TOKENS_PER_ETH;
    require(balanceOf(msg.sender) >= tokenAmount, "Insufficient balance");
    _burn(msg.sender, tokenAmount);
    payable(msg.sender).transfer(ethAmount);
  }
}
