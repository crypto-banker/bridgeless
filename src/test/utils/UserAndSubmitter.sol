// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "forge-std/Test.sol";

abstract contract UserAndSubmitter is Test 
{
    Vm cheats = Vm(HEVM_ADDRESS);

    uint256 user_priv_key = uint256(keccak256("pseudorandom-address-01"));
    address payable user = payable(cheats.addr(user_priv_key));

    uint256 submitter_priv_key = uint256(keccak256("pseudorandom-address-02"));
    address payable submitter = payable(cheats.addr(submitter_priv_key));
}