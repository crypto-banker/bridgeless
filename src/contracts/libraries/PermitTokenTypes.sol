// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "./IERC2612.sol";
import "./IDAILikePermit.sol";

library PermitTokenTypes {
    struct ERC2612_Permit {
        address owner;
        address spender;
        uint256 value;
        uint256 nonce;
        uint256 deadline;
        bytes32 domainSeparator;
    }

    struct DAILike_Permit {
        address owner;
        address spender;
        uint256 nonce;
        uint256 expiry;
        bool allowed;
        bytes32 domainSeparator;
    }

    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)")
    bytes32 public constant ERC2612_PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    // bytes32 public constant PERMIT_TYPEHASH = keccak256("Permit(address holder,address spender,uint256 nonce,uint256 expiry,bool allowed)");
    bytes32 public constant DAILIKE_PERMIT_TYPEHASH = 0xea2aa0a1be11a07ed86d755c93467f4f82362b452371d1ba94d1715123511acb;


    function findDomainSeparator_DAILike(
        IDAILikePermit permitToken
    )
        public view returns (bytes32 DOMAIN_SEPARATOR)
    {
        DOMAIN_SEPARATOR = findDomainSeparator_DAILike(
            permitToken,
            block.chainid,
            permitToken.name(),
            permitToken.version()
        );
        return DOMAIN_SEPARATOR;
    }


    function findDomainSeparator_DAILike(
        IDAILikePermit permitToken,
        uint256 chainId,
        string memory name,
        string memory version
    )
        public pure returns (bytes32 DOMAIN_SEPARATOR)
    {
        // calculation from DAI code here -- https://etherscan.io/address/0x6b175474e89094c44da98b954eedeac495271d0f#code
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256(bytes(name)),
            keccak256(bytes(version)),
            chainId,
            address(permitToken)
        ));
        return DOMAIN_SEPARATOR;
    }

    function findDomainSeparator_ERC2612(
        IERC2612 permitToken
    )
        public view returns (bytes32 DOMAIN_SEPARATOR)
    {
        DOMAIN_SEPARATOR = findDomainSeparator_ERC2612(
            permitToken,
            block.chainid,
            permitToken.name(),
            permitToken.version()
        );
        return DOMAIN_SEPARATOR;
    }

    function findDomainSeparator_ERC2612(
        IERC2612 permitToken,
        uint256 chainId,
        string memory name,
        string memory version
    )
        public pure returns (bytes32 DOMAIN_SEPARATOR)
    {
        // calculation from USDC implementation code here -- https://etherscan.io/address/0xa2327a938febf5fec13bacfb16ae10ecbc4cbdcf#code
        DOMAIN_SEPARATOR = 
            keccak256(
                abi.encode(
                    // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
                    0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f,
                    keccak256(bytes(name)),
                    keccak256(bytes(version)),
                    chainId,
                    address(permitToken)
                )
        );
        return DOMAIN_SEPARATOR;
    }



    // ERC2612-compliant ("IERC20Permit") Tokens

    function findPermitHash_FromArgs_ERC2612(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        IERC2612 permitToken
    )
        public view returns (bytes32 permitHash)
    {
        // fetch info from token
        uint256 nonce = permitToken.nonces(owner);
        bytes32 domainSeparator = permitToken.DOMAIN_SEPARATOR();

        ERC2612_Permit memory permitStruct = ERC2612_Permit_FromArgs(
            owner,
            spender,
            value,
            nonce,
            deadline,
            domainSeparator
        );

        // get the permit hash
        permitHash = findPermitHash_ERC2612(permitStruct);

        return permitHash;
    }

    function findPermitHash_ERC2612(
        ERC2612_Permit memory permitStruct
    ) 
        public pure returns (bytes32 permitHash) 
    {
        // calculation from USDC implementation code here -- https://etherscan.io/address/0xa2327a938febf5fec13bacfb16ae10ecbc4cbdcf#code
        bytes memory data = abi.encode(
            ERC2612_PERMIT_TYPEHASH,
            permitStruct.owner,
            permitStruct.spender,
            permitStruct.value,
            permitStruct.nonce,
            permitStruct.deadline
        );
        permitHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                permitStruct.domainSeparator,
                keccak256(data)
            )
        );

        return permitHash;
    }

    function ERC2612_Permit_FromArgs(
        address owner,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline,
        bytes32 domainSeparator
    )
        public pure returns (ERC2612_Permit memory permitStruct) 
    {
        permitStruct = ERC2612_Permit({
            owner: owner,
            spender: spender,
            value: value,
            nonce: nonce,
            deadline: deadline,
            domainSeparator: domainSeparator
        });

        return permitStruct;
    }






    // DAI-Like Tokens

    function findPermitHash_FromArgs_DAILike(
        address owner,
        address spender,
        uint256 expiry,
        bool allowed,
        IDAILikePermit permitToken
    )
        public view returns (bytes32 permitHash)
    {
        // fetch info from token
        uint256 nonce = permitToken.nonces(owner);
        bytes32 domainSeparator = permitToken.DOMAIN_SEPARATOR();

        DAILike_Permit memory permitStruct = DAILike_Permit_FromArgs(
            owner,
            spender,
            nonce,
            expiry,
            allowed,
            domainSeparator
        );

        // get the permit hash
        permitHash = findPermitHash_DAILike(permitStruct);

        return permitHash;
    }

    function findPermitHash_DAILike(
        DAILike_Permit memory permitStruct
    ) 
        public pure returns (bytes32 permitHash) 
    {
        // calculation from DAI code here -- https://etherscan.io/address/0x6b175474e89094c44da98b954eedeac495271d0f#code

        permitHash =
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    permitStruct.domainSeparator,
                    keccak256(
                        abi.encode(
                            DAILIKE_PERMIT_TYPEHASH,
                            permitStruct.owner,
                            permitStruct.spender,
                            permitStruct.nonce,
                            permitStruct.expiry,
                            permitStruct.allowed
                        )
                    )
                )
        );

        return permitHash;
    }

    function DAILike_Permit_FromArgs(
        address owner,
        address spender,
        uint256 nonce,
        uint256 expiry,
        bool allowed,
        bytes32 domainSeparator
    )
        public pure returns (DAILike_Permit memory permitStruct) 
    {
        permitStruct = DAILike_Permit({
            owner: owner,
            spender: spender,
            nonce: nonce,
            expiry: expiry,
            allowed: allowed,
            domainSeparator: domainSeparator
        });

        return permitStruct;
    }

}
