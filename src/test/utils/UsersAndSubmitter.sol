// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "forge-std/Test.sol";

abstract contract UsersAndSubmitter is 
    DSTest 
{
    Vm cheats = Vm(HEVM_ADDRESS);

    uint256 user_priv_key;
    address payable user;
    
    uint256 submitter_priv_key = uint256(keccak256("pseudorandom-address-99"));
    address payable submitter = payable(cheats.addr(submitter_priv_key));

    address[] public users;
    uint256[] public user_priv_keys;

    function setUpUsers(uint8 numberUsers) public {
        user_priv_key = uint256(keccak256("pseudorandom-address-00"));
        user = payable(cheats.addr(user_priv_key));
        for (uint8 i; i < numberUsers; ++i) {
            user_priv_keys.push(user_priv_key);
            users.push(user);
            _getNextUser();
        }
    }

    function _getNextUser() internal {
        user_priv_key = uint256(keccak256(abi.encodePacked(user_priv_key)));
        user = payable(cheats.addr(user_priv_key));
    }   
}