// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title MockProtocol - імітація протоколу з комісією, яку може змінювати лише власник
contract MockProtocol is Ownable {
    uint256 public fee;

    event FeeChanged(uint256 oldFee, uint256 newFee);

    constructor(uint256 initialFee) Ownable(msg.sender) {
        fee = initialFee;
    }

    function setFee(uint256 newFee) external onlyOwner {
        emit FeeChanged(fee, newFee);
        fee = newFee;
    }
}
