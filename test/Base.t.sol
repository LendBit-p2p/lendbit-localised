// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "@chainlink/contracts/src/v0.8/shared/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/shared/mocks/MockV3Aggregator.sol";

contract Base is Test {
    function deployERC20ContractAndAddPriceFeed(string memory _name, uint8 _decimals, int256 _initialAnswer)
        internal
        returns (address, address)
    {
        ERC20Mock _erc20 = new ERC20Mock(_decimals);
        MockV3Aggregator priceFeed = new MockV3Aggregator(8, _initialAnswer * 1e8);
        vm.label(address(priceFeed), "Price Feed");
        vm.label(address(_erc20), _name);
        return (address(_erc20), address(priceFeed));
    }

    function mkaddr(string memory name) public returns (address) {
        address addr = address(uint160(uint256(keccak256(abi.encodePacked(name)))));
        vm.label(addr, name);
        return addr;
    }
}
