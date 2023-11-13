// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title eNRS
 * @author sandman
 */
 contract eNRS is ERC20Burnable, Ownable(msg.sender) {
    error eNRS_LessThanZero();
    error eNRS_NotEnoughBalance(uint256);
    error eNRS_NotZeroAddress();

    constructor()  ERC20("Nepali Rupees", "eNRS") {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert eNRS_LessThanZero();
        }
        if (balance < _amount) {
            revert eNRS_NotEnoughBalance(_amount);
        }
        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert eNRS_NotZeroAddress();
        }
        if (_amount <= 0) {
            revert eNRS_LessThanZero();
        }
        _mint(_to, _amount);
        return true;
    }
}
