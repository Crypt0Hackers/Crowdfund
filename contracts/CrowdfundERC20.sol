// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CrowdfundERC20 is ERC20 {
    constructor() ERC20("CROWDFUND", "CRW") {}

    function mint() external payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw() external payable {
        uint amountToWithdraw = balanceOf(msg.sender);

        _burn(msg.sender, amountToWithdraw);
        (bool success, ) = payable(msg.sender).call{value: amountToWithdraw}("");

        if (!success) revert();
    }

    function giveApproval(address crowdfund) external {
        approve(crowdfund, type(uint256).max);
    }
}

