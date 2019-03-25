pragma solidity ^0.4.25;

/*******************************************************************************
 *
 * Copyright (c) 2019 Decentralization Authority MDAO.
 * Released under the MIT License.
 *
 * Residency - Universal Loyalty Program for the Zer0net Community
 *
 *             Residents are required to staek their memberships in ZeroGold.
 *
 *             Membership benefits include:
 *                 - Unlimited Access to Premium (Resident) Services
 *                 - Notification of Exclusive Zer0net Deals & Offers
 *
 * Version 19.3.25
 *
 * https://d14na.org
 * support@d14na.org
 */


/*******************************************************************************
 *
 * SafeMath
 */
library SafeMath {
    function add(uint a, uint b) internal pure returns (uint c) {
        c = a + b;
        require(c >= a);
    }
    function sub(uint a, uint b) internal pure returns (uint c) {
        require(b <= a);
        c = a - b;
    }
    function mul(uint a, uint b) internal pure returns (uint c) {
        c = a * b;
        require(a == 0 || c / a == b);
    }
    function div(uint a, uint b) internal pure returns (uint c) {
        require(b > 0);
        c = a / b;
    }
}


/*******************************************************************************
 *
 * ECRecovery
 *
 * Contract function to validate signature of pre-approved token transfers.
 * (borrowed from LavaWallet)
 */
contract ECRecovery {
    function recover(bytes32 hash, bytes sig) public pure returns (address);
}


/*******************************************************************************
 *
 * ERC Token Standard #20 Interface
 * https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20-token-standard.md
 */
contract ERC20Interface {
    function totalSupply() public constant returns (uint);
    function balanceOf(address tokenOwner) public constant returns (uint balance);
    function allowance(address tokenOwner, address spender) public constant returns (uint remaining);
    function transfer(address to, uint tokens) public returns (bool success);
    function approve(address spender, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}


/*******************************************************************************
 *
 * ApproveAndCallFallBack
 *
 * Contract function to receive approval and execute function in one call
 * (borrowed from MiniMeToken)
 */
contract ApproveAndCallFallBack {
    function approveAndCall(address spender, uint tokens, bytes data) public;
    function receiveApproval(address from, uint256 tokens, address token, bytes data) public;
}


/*******************************************************************************
 *
 * Owned contract
 */
contract Owned {
    address public owner;
    address public newOwner;

    event OwnershipTransferred(address indexed _from, address indexed _to);

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        newOwner = _newOwner;
    }

    function acceptOwnership() public {
        require(msg.sender == newOwner);

        emit OwnershipTransferred(owner, newOwner);

        owner = newOwner;

        newOwner = address(0);
    }
}


/*******************************************************************************
 *
 * Zer0netDb Interface
 */
contract Zer0netDbInterface {
    /* Interface getters. */
    function getAddress(bytes32 _key) external view returns (address);
    function getBool(bytes32 _key)    external view returns (bool);
    function getBytes(bytes32 _key)   external view returns (bytes);
    function getInt(bytes32 _key)     external view returns (int);
    function getString(bytes32 _key)  external view returns (string);
    function getUint(bytes32 _key)    external view returns (uint);

    /* Interface setters. */
    function setAddress(bytes32 _key, address _value) external;
    function setBool(bytes32 _key, bool _value) external;
    function setBytes(bytes32 _key, bytes _value) external;
    function setInt(bytes32 _key, int _value) external;
    function setString(bytes32 _key, string _value) external;
    function setUint(bytes32 _key, uint _value) external;

    /* Interface deletes. */
    function deleteAddress(bytes32 _key) external;
    function deleteBool(bytes32 _key) external;
    function deleteBytes(bytes32 _key) external;
    function deleteInt(bytes32 _key) external;
    function deleteString(bytes32 _key) external;
    function deleteUint(bytes32 _key) external;
}


/*******************************************************************************
 *
 * ZeroCache Interface
 */
contract ZeroCacheInterface {
    function balanceOf(address _token, address _owner) public constant returns (uint balance);
    function transfer(address _to, address _token, uint _tokens) external returns (bool success);
    function transfer(address _token, address _from, address _to, uint _tokens, address _staekholder, uint _staek, uint _expires, uint _nonce, bytes _signature) external returns (bool success);
}


/*******************************************************************************
 *
 * Staek(house) Factory Interface
 */
contract StaekFactoryInterface {
    function balanceOf(bytes32 _staekhouseId, address _owner) public view returns (uint balance);
    function getStaekhouse(bytes32 _staekhouseId, address _staeker) external view returns (address factory, address token, address owner, uint staekLockTime, uint debtLockTime, uint debtLimit, uint lockInterval, uint balance);
}


/*******************************************************************************
 *
 * Wrapped ETH (WETH) Interface
 */
contract WETHInterface {
    function() public payable;
    function deposit() public payable ;
    function withdraw(uint wad) public;
    function totalSupply() public view returns (uint);
    function approve(address guy, uint wad) public returns (bool);
    function transfer(address dst, uint wad) public returns (bool);
    function transferFrom(address src, address dst, uint wad) public returns (bool);

    event Approval(address indexed src, address indexed guy, uint wad);
    event Transfer(address indexed src, address indexed dst, uint wad);
    event Deposit(address indexed dst, uint wad);
    event Withdrawal(address indexed src, uint wad);
}


/*******************************************************************************
 *
 * @notice Residency Loyalty Program
 *
 * @dev Permissioned access to zer0net premium services.
 */
contract Residency is Owned {
    using SafeMath for uint;

    /* Initialize predecessor contract. */
    address private _predecessor;

    /* Initialize successor contract. */
    address private _successor;

    /* Initialize revision number. */
    uint private _revision;

    /* Initialize Zer0net Db contract. */
    Zer0netDbInterface private _zer0netDb;

    /**
     * Set Namespace
     *
     * Provides a "unique" name for generating "unique" data identifiers,
     * most commonly used as database "key-value" keys.
     *
     * NOTE: Use of `namespace` is REQUIRED when generating ANY & ALL
     *       Zer0netDb keys; in order to prevent ANY accidental or
     *       malicious SQL-injection vulnerabilities / attacks.
     */
    string private _namespace = 'residency';

    /**
     * (Primary) Membership Classification
     *
     * GUEST - No active usage
     * HODL  - Investment and speculation
     * SPEDN - Electronic commerce
     * STAEK - Collateral and escrow
     * WHAEL - Accredited investments
     */
    enum MembershipClass {
        GUEST,
        HODL,
        SPEDN,
        STAEK,
        WHAEL
    }

    /* Initialize number of ZeroGold decimals. */
    uint _ZEROGOLD_DECIMALS = 8;

    /* Initialize number of Dai decimals. */
    uint _DAI_DECIMALS = 18;

    /* Initialize membership block counts. */
    uint _DAILY_MEMBERSHIP_BLOCKS = 6000;
    uint _WEEKLY_MEMBERSHIP_BLOCKS = 41000;
    uint _MONTHLY_MEMBERSHIP_BLOCKS = 175000;
    uint _YEARLY_MEMBERSHIP_BLOCKS = 2100000;

    /* Initialize members. */
    mapping(address => uint) private _members;

    /* Initialize the membership rates (in DAI). */
    // FIXME Allow rates to be set by admin.
    uint _dailyRate   =   250000000000000000; //  $0.25 DAI - 11 0GOLD @ genesis
    uint _weeklyRate  =  1490000000000000000; //  $1.49 DAI - 63 0GOLD @ genesis
    uint _monthlyRate =  4990000000000000000; //  $4.99 DAI - 210 0GOLD @ genesis
    uint _yearlyRate  = 39990000000000000000; // $39.99 DAI - 1,680 0GOLD @ genesis

    /* Initialize events. */
    event Membership(
        address indexed memberId,
        uint expiration
    );

    /***************************************************************************
     *
     * Constructor
     */
    constructor() public {
        /* Initialize Zer0netDb (eternal) storage database contract. */
        // NOTE We hard-code the address here, since it should never change.
        // _zer0netDb = Zer0netDbInterface(0xE865Fe1A1A3b342bF0E2fcB11fF4E3BCe58263af);
        _zer0netDb = Zer0netDbInterface(0x4C2f68bCdEEB88764b1031eC330aD4DF8d6F64D6); // ROPSTEN

        /* Initialize (aname) hash. */
        bytes32 hash = keccak256(abi.encodePacked('aname.', _namespace));

        /* Set predecessor address. */
        _predecessor = _zer0netDb.getAddress(hash);

        /* Verify predecessor address. */
        if (_predecessor != 0x0) {
            /* Retrieve the last revision number (if available). */
            uint lastRevision = Residency(_predecessor).getRevision();

            /* Set (current) revision number. */
            _revision = lastRevision + 1;
        }
    }

    /**
     * @dev Only allow access to an authorized Zer0net administrator.
     */
    modifier onlyAuthBy0Admin() {
        /* Verify write access is only permitted to authorized accounts. */
        require(_zer0netDb.getBool(keccak256(
            abi.encodePacked(msg.sender, '.has.auth.for.', _namespace))) == true);

        _;      // function code is inserted here
    }

    /**
     * THIS CONTRACT DOES NOT ACCEPT DIRECT ETHER
     */
    function () public payable {
        /* Cancel this transaction. */
        revert('Oops! Direct payments are NOT permitted here.');
    }


    /***************************************************************************
     *
     * ACTIONS
     *
     */

    /**
     * Add (NEW) Membership
     */
    function addMembership(
        address _memberId,
        bytes32 _staekhouseId
    ) external returns (bool success) {
        /* Add membership. */
        return _addMembership(
            _memberId,
            _staekhouseId
        );
    }

    /**
     * Add (NEW) Membership
     *
     * NOTE: Creates a profile for new member.
     *       NOTE: Will fail, if member already exists.
     */
    function _addMembership(
        address _memberId,
        bytes32 _staekhouseId
    ) private returns (bool success) {
        /* Validate pre-existing membership. */
        if (_members[_memberId] > 0) {
            revert('Oops! This account already exists.');
        }

        /* Initialize expiration. */
        uint expiration = 0;

        // FIXME Calculate expiration from staekhouse recipe

        /* Retrieve staekhouse configuration. */
        (
            address factory,
            address token,
            address owner,
            uint staekLockTime,
            uint debtLockTime,
            uint debtLimit,
            uint lockInterval,
            uint balance
        ) = _staekFactory(_staekhouseId)
            .getStaekhouse(_staekhouseId, _memberId);

        // TEMPORARY VALIDATION

        if (factory == 0x0) {
            revert('Oops! That factory is INVALID.');
        }

        if (token == 0x0) {
            revert('Oops! That token is INVALID.');
        }

        if (owner == 0x0) {
            revert('Oops! That owner is INVALID.');
        }

        if (staekLockTime < block.number) {
            revert('Oops! That block number is INVALID.');
        }

        if (debtLockTime < block.number) {
            revert('Oops! That debt lock time is INVALID.');
        }

        if (debtLimit > balance) {
            revert('Oops! That debt limit is INVALID.');
        }

        if (lockInterval == 0) {
            revert('Oops! That lock interval is INVALID.');
        }

        /* Calculate the expiration time. */
        // if (_class == MembershipClass.Monthly) {
        //     expiration = now + 30 days;
        // } else if (_class == MembershipClass.Yearly) {
        //     expiration = now + 365 days;
        // }

        /* Set the expiration time. */
        _members[_memberId] = expiration;
        // _members[_memberId] = block.number + 10;

        /* Send an event notice. */
        emit Membership(
            _memberId,
            expiration
        );

        /* Return success. */
        return true;
    }


    /***************************************************************************
     *
     * GETTERS
     *
     */

    /**
     * Get Membership Rate
     *
     * Membership       Fee     STAEK Lvl*    Duration       Min Lock Time
     * -------------------------------------------------------------------
     *
     * Daily         $0.25 DAI      1x         ~1 day         6,000 blocks
     * Weekly        $1.49 DAI      2x         ~7 days       41,000 blocks
     * Monthly       $4.99 DAI      3x        ~30 days      175,000 blocks
     * Yearly       $39.99 DAI      5x       ~365 days    2,100,000 blocks
     *
     * NOTE: Staek Lvl is the pre-set multiplier used to calculate the
     *       Total Staek Value (TSV) held in the staekhouse.
     */
    function getMembershipRate(
        uint _staek
    ) public view returns (uint rate) {
        /* Initialize SPOT PRICE hash. */
        bytes32 hash = keccak256(abi.encodePacked(
            'zpi.0GOLD.DAI'
        ));

        /* Retrieve value from Zer0net Db. */
        // NOTE: This number has 18 decimals.
        uint spotPrice = _zer0netDb.getUint(hash);

        /* Calculate daily staek. */
        uint dailyStaek = _dailyRate
            .mul(10**_ZEROGOLD_DECIMALS)
            .div(spotPrice);

        /* Calculate weekly staek. */
        uint weeklyStaek = _weeklyRate
            .mul(10**_ZEROGOLD_DECIMALS)
            .div(spotPrice);

        /* Calculate monthly staek. */
        uint monthlyStaek = _monthlyRate
            .mul(10**_ZEROGOLD_DECIMALS)
            .div(spotPrice);

        /* Calculate yearly staek. */
        uint yearlyStaek = _yearlyRate
            .mul(10**_ZEROGOLD_DECIMALS)
            .div(spotPrice);

        /* Calculate minimum staek rate. */
        if (_staek > yearlyStaek.mul(5)) { // Staek Lvl is 5x
            /* Set rate. */
            rate = _yearlyRate;
        } else if (_staek > monthlyStaek.mul(3)) { // Staek Lvl is 3x
            /* Set rate. */
            rate = _monthlyRate;
        } else if (_staek > weeklyStaek.mul(2)) { // Staek Lvl is 2x
            /* Set rate. */
            rate = _weeklyRate;
        } else if (_staek > dailyStaek) { // Staek Lvl is 1x
            /* Set rate. */
            rate = _dailyRate;
        } else {
            /* Set rate. */
            rate = 0;
        }
    }

    /**
     * Get Expiration
     */
    function getExpiration(
        address _memberId
    ) external view returns (uint expiration) {
        /* Retrieve expiration. */
        expiration = _members[_memberId];
    }

    /**
     * Get (Membership) Class
     */
    function getClass(
        address _memberId
    ) public view returns (MembershipClass class) {
        /* Initialize hash. */
        bytes32 hash = 0x0;

        /* Retrieve member WETH balance. */
        uint wethBalance = _zeroCache().balanceOf(_weth(), _memberId);

        /* Initialize SPOT PRICE hash. */
        hash = keccak256(abi.encodePacked(
            'zpi.0GOLD.WETH'
        ));

        /* Retrieve value from Zer0net Db. */
        // NOTE: This number has 18 decimals.
        uint wethSpotPrice = _zer0netDb.getUint(hash);

        /* Calculate WETH/DAI value. */
        uint wethDai = wethBalance
            .mul(wethSpotPrice)
            .div(10**_DAI_DECIMALS);

        /* Retrieve member DAI balance. */
        uint daiBalance = _zeroCache().balanceOf(_dai(), _memberId);

        /* Retrieve member ZeroGold balance. */
        uint zgBalance = _zeroCache().balanceOf(_zeroGold(), _memberId);

        /* Initialize SPOT PRICE hash. */
        hash = keccak256(abi.encodePacked(
            'zpi.0GOLD.WETH'
        ));

        /* Retrieve value from Zer0net Db. */
        // NOTE: This number has 18 decimals.
        uint zgSpotPrice = _zer0netDb.getUint(hash);

        /* Calculate 0GOLD/DAI value. */
        uint zgDai = zgBalance
            .mul(zgSpotPrice)
            .div(10**_DAI_DECIMALS);

        /* Calculate the class (based on balance values). */
        // NOTE: WHAEL status is NOT YET IMPLEMENTED
        if (wethDai > daiBalance && wethDai > zgDai) {
            /* Return class. */
            class =  MembershipClass.HODL;
        } else if (daiBalance > wethDai && daiBalance > zgDai) {
            /* Return class. */
            class =  MembershipClass.SPEDN;
        } else if (zgDai > daiBalance && zgDai > wethDai) {
            /* Return class. */
            class =  MembershipClass.STAEK;
        } else {
            /* Return class. */
            class =  MembershipClass.GUEST;
        }
    }

    /**
     * Get Member
     */
    function getMember(
        address _memberId
    ) public view returns (
        bool isMember,
        MembershipClass class,
        uint expiration
    ) {
        /* Retrieve membership class. */
        class = getClass(_memberId);

        /* Retrieve expiration. */
        expiration = _members[_memberId];

        /* Validate membership. */
        if (expiration > block.number) {
            isMember = true;
        } else {
            isMember = false;
        }
    }

    /**
     * Get Revision (Number)
     */
    function getRevision() public view returns (uint) {
        return _revision;
    }

    /**
     * Get Predecessor (Address)
     */
    function getPredecessor() public view returns (address) {
        return _predecessor;
    }

    /**
     * Get Successor (Address)
     */
    function getSuccessor() public view returns (address) {
        return _successor;
    }


    /***************************************************************************
     *
     * SETTERS
     *
     */

    /**
     * Set Successor
     *
     * This is the contract address that replaced this current instnace.
     */
    function setSuccessor(
        address _newSuccessor
    ) onlyAuthBy0Admin external returns (bool success) {
        /* Set successor contract. */
        _successor = _newSuccessor;

        /* Return success. */
        return true;
    }


    /***************************************************************************
     *
     * INTERFACES
     *
     */

    /**
     * Supports Interface (EIP-165)
     *
     * (see: https://github.com/ethereum/EIPs/blob/master/EIPS/eip-165.md)
     *
     * NOTE: Must support the following conditions:
     *       1. (true) when interfaceID is 0x01ffc9a7 (EIP165 interface)
     *       2. (false) when interfaceID is 0xffffffff
     *       3. (true) for any other interfaceID this contract implements
     *       4. (false) for any other interfaceID
     */
    function supportsInterface(
        bytes4 _interfaceID
    ) external pure returns (bool) {
        /* Initialize constants. */
        bytes4 InvalidId = 0xffffffff;
        bytes4 ERC165Id = 0x01ffc9a7;

        /* Validate condition #2. */
        if (_interfaceID == InvalidId) {
            return false;
        }

        /* Validate condition #1. */
        if (_interfaceID == ERC165Id) {
            return true;
        }

        // TODO Add additional interfaces here.

        /* Return false (for condition #4). */
        return false;
    }

    /**
     * ECRecovery Interface
     */
    function _ecRecovery() private view returns (
        ECRecovery ecrecovery
    ) {
        /* Initialize hash. */
        bytes32 hash = keccak256('aname.ecrecovery');

        /* Retrieve value from Zer0net Db. */
        address aname = _zer0netDb.getAddress(hash);

        /* Initialize interface. */
        ecrecovery = ECRecovery(aname);
    }

    /**
     * ZeroCache Interface
     *
     * Retrieves the current ZeroCache interface,
     * using the aname record from Zer0netDb.
     */
    function _zeroCache() private view returns (
        ZeroCacheInterface zeroCache
    ) {
        /* Initialize hash. */
        bytes32 hash = keccak256('aname.zerocache');

        /* Retrieve value from Zer0net Db. */
        address aname = _zer0netDb.getAddress(hash);

        /* Initialize interface. */
        zeroCache = ZeroCacheInterface(aname);
    }

    /**
     * Wrapped Ether (WETH) Interface
     *
     * Retrieves the current WETH interface,
     * using the aname record from Zer0netDb.
     */
    function _weth() private view returns (
        WETHInterface weth
    ) {
        /* Initailze hash. */
        // NOTE: ERC tokens are case-sensitive.
        bytes32 hash = keccak256('aname.WETH');

        /* Retrieve value from Zer0net Db. */
        address aname = _zer0netDb.getAddress(hash);

        /* Initialize interface. */
        weth = WETHInterface(aname);
    }

    /**
     * MakerDAO DAI Interface
     *
     * Retrieves the current DAI interface,
     * using the aname record from Zer0netDb.
     */
    function _dai() private view returns (
        ERC20Interface dai
    ) {
        /* Initialize hash. */
        // NOTE: ERC tokens are case-sensitive.
        bytes32 hash = keccak256('aname.DAI');

        /* Retrieve value from Zer0net Db. */
        address aname = _zer0netDb.getAddress(hash);

        /* Initialize interface. */
        dai = ERC20Interface(aname);
    }

    /**
     * ZeroGold Interface
     *
     * Retrieves the current ZeroGold interface,
     * using the aname record from Zer0netDb.
     */
    function _zeroGold() private view returns (
        ERC20Interface zeroGold
    ) {
        /* Initialize hash. */
        // NOTE: ERC tokens are case-sensitive.
        bytes32 hash = keccak256('aname.0GOLD');

        /* Retrieve value from Zer0net Db. */
        address aname = _zer0netDb.getAddress(hash);

        /* Initialize interface. */
        zeroGold = ERC20Interface(aname);
    }

    /**
     * Staek Factory Interface
     *
     * Retrieves the current Staek Factory interface,
     * using the aname record from Zer0netDb.
     */
    function _staekFactory(
        bytes32 _staekhouseId
    ) private view returns (
        StaekFactoryInterface staekFactory
    ) {
        /* Retrieve factory location from Zer0net Db. */
        address aname = _zer0netDb.getAddress(_staekhouseId);

        /* Initialize interface. */
        staekFactory = StaekFactoryInterface(aname);
    }


    /***************************************************************************
     *
     * UTILITIES
     *
     */

    /**
     * Validate Staekhouse Recipe
     */
    function _recipeIsValid(
        uint _staekLockTime,
        uint _staek
    ) private view returns (bool isValid) {
        /* Validate staek value. */
        if (_staek == 0) {
            return false;
        }

        /* Initialize validity flag. */
        isValid = false;

        /* Initialize SPOT PRICE hash. */
        bytes32 hash = keccak256(abi.encodePacked(
            'zpi.0GOLD.DAI'
        ));

        /* Retrieve value from Zer0net Db. */
        // NOTE: This number has 18 decimals.
        uint spotPrice = _zer0netDb.getUint(hash);

        /* Calculate daily staek. */
        uint dailyStaek = _dailyRate
            .mul(10**_ZEROGOLD_DECIMALS)
            .div(spotPrice);

        /* Calculate weekly staek. */
        uint weeklyStaek = _weeklyRate
            .mul(10**_ZEROGOLD_DECIMALS)
            .div(spotPrice);

        /* Calculate monthly staek. */
        uint monthlyStaek = _monthlyRate
            .mul(10**_ZEROGOLD_DECIMALS)
            .div(spotPrice);

        /* Calculate yearly staek. */
        uint yearlyStaek = _yearlyRate
            .mul(10**_ZEROGOLD_DECIMALS)
            .div(spotPrice);

        /* Validate membership lock time. */
        // NOTE: Staekers must meet the minimum block times.
        if (
            _staekLockTime > block.number + _YEARLY_MEMBERSHIP_BLOCKS &&
            _staek > yearlyStaek.mul(5) // Staek Lvl is 5x
        ) {
            /* Set validity flag. */
            isValid = true;
        } else if (
            _staekLockTime > block.number + _MONTHLY_MEMBERSHIP_BLOCKS &&
            _staek > monthlyStaek.mul(3) // Staek Lvl is 3x
        ) {
            /* Set validity flag. */
            isValid = true;
        } else if (
            _staekLockTime > block.number + _WEEKLY_MEMBERSHIP_BLOCKS &&
            _staek > weeklyStaek.mul(2) // Staek Lvl is 2x
        ) {
            /* Set validity flag. */
            isValid = true;
        } else if (
            _staekLockTime > block.number + _DAILY_MEMBERSHIP_BLOCKS &&
            _staek > dailyStaek // Staek Lvl is 1x
        ) {
            /* Set validity flag. */
            isValid = true;
        }
    }

    /**
     * Bytes-to-Address
     *
     * Converts bytes into type address.
     */
    function _bytesToAddress(
        bytes _address
    ) private pure returns (address) {
        uint160 m = 0;
        uint160 b = 0;

        for (uint8 i = 0; i < 20; i++) {
            m *= 256;
            b = uint160(_address[i]);
            m += (b);
        }

        return address(m);
    }

    /**
     * Convert Bytes to Bytes32
     */
    function _bytesToBytes32(
        bytes _data,
        uint _offset
    ) private pure returns (bytes32 result) {
        /* Loop through each byte. */
        for (uint i = 0; i < 32; i++) {
            /* Shift bytes onto result. */
            result |= bytes32(_data[i + _offset] & 0xFF) >> (i * 8);
        }
    }

    /**
     * Transfer Any ERC20 Token
     *
     * @notice Owner can transfer out any accidentally sent ERC20 tokens.
     *
     * @dev Provides an ERC20 interface, which allows for the recover
     *      of any accidentally sent ERC20 tokens.
     */
    function transferAnyERC20Token(
        address _tokenAddress,
        uint _tokens
    ) public onlyOwner returns (bool success) {
        return ERC20Interface(_tokenAddress).transfer(owner, _tokens);
    }
}
