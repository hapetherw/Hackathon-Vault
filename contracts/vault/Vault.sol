// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "../../interfaces/IStrategy.sol";

/**
 * @title minimized Vault of USDs protocol
 * @author Sperax Foundation
 */
contract Vault is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;

    event CollateralAdded(
        address collateralAddr,
        bool addded,
        address defaultStrategyAddr
    );
    event StrategyAdded(address strategyAddr, bool added);
    event CollateralAllocated(
        address indexed collateralAddr,
        address indexed depositStrategyAddr,
        uint256 allocateAmount
    );
    event TotalValueLocked(
        uint256 totalValueLocked,
        uint256 totalValueInVault,
        uint256 totalValueInStrategies
    );

    struct collateralStruct {
        address collateralAddr;
        bool added;
        address defaultStrategyAddr;
    }
    struct strategyStruct {
        address strategyAddr;
        bool added;
    }
    mapping(address => collateralStruct) public collateralsInfo;
    mapping(address => strategyStruct) public strategiesInfo;

    address[] public allCollateralAddr; // the list of all added collaterals
    address[] public allStrategyAddr; // the list of all strategy addresses

    /**
     * @dev contract initializer
     */
    function initialize() public initializer {
        OwnableUpgradeable.__Ownable_init();
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
    }

    /**
     * @dev authorize an ERC20 token as one of the collaterals supported by USDs mint/redeem
     * @param _collateralAddr ERC20 address to be authorized
     * @param _defaultStrategyAddr strategy address of which the collateral is allocated into on allocate()
     */
    function addCollateral(
        address _collateralAddr,
        address _defaultStrategyAddr
    ) external onlyOwner {
        require(!collateralsInfo[_collateralAddr].added, "Collateral added");
        require(
            ERC20Upgradeable(_collateralAddr).decimals() <= 18,
            "Collaterals decimals need to be less than 18"
        );
        collateralStruct storage addingCollateral = collateralsInfo[
            _collateralAddr
        ];
        addingCollateral.collateralAddr = _collateralAddr;
        addingCollateral.added = true;
        addingCollateral.defaultStrategyAddr = _defaultStrategyAddr;
        allCollateralAddr.push(addingCollateral.collateralAddr);
        emit CollateralAdded(
            _collateralAddr,
            addingCollateral.added,
            _defaultStrategyAddr
        );
    }

    /**
     * @dev authorize an strategy
     * @param _strategyAddr strategy contract address
     */
    function addStrategy(address _strategyAddr) external onlyOwner {
        require(!strategiesInfo[_strategyAddr].added, "Strategy added");
        strategyStruct storage addingStrategy = strategiesInfo[_strategyAddr];
        addingStrategy.strategyAddr = _strategyAddr;
        addingStrategy.added = true;
        allStrategyAddr.push(addingStrategy.strategyAddr);
        emit StrategyAdded(_strategyAddr, true);
    }

    /**
     * @notice harvest USDs held by VaultCore
     * @dev VaultCore does not organically hold/generate USDs, transfer USDs to
     *		VaultCore manually
     */
    function harvest() external onlyOwner nonReentrant {
        IStrategy strategy;
        collateralStruct memory collateral;
        for (uint256 y = 0; y < allCollateralAddr.length; y++) {
            collateral = collateralsInfo[allCollateralAddr[y]];
            if (collateral.defaultStrategyAddr != address(0)) {
                strategy = IStrategy(collateral.defaultStrategyAddr);
                require(strategy.supportsCollateral(collateral.collateralAddr));
                _harvestInterest(strategy, collateral.collateralAddr);
                _harvestReward(strategy);
            }
        }
    }

    /**
     * @notice harvest reward token earned in strategies
     * @dev rewardLiquidationThreshold is the maximum amount of CRV used to
     * 		rebase; the rest is sent to rwdReserve.
     */
    function _harvestReward(IStrategy strategy) internal {
        address rwdTokenAddr = strategy.rewardTokenAddress();
        uint256 rewardEarned = strategy.checkRewardEarned();
        if (rewardEarned > 0) {
            uint256 rerwardCollected = strategy.collectRewardToken();
        }
    }

    /**
     * @notice harvest interest earned in strategies
     * @dev interestLiquidationThreshold is the maximum interest allowed;
     *		if interest earned is higher than that, txn will be reverted. Lower
     *		rewardLiquidationThreshold and increase interestLiquidationThreshold
     */
    function _harvestInterest(IStrategy strategy, address collateralAddr)
        internal
    {
        collateralStruct memory collateral = collateralsInfo[collateralAddr];
        uint256 interestEarned = strategy.checkInterestEarned(collateralAddr);
        if (interestEarned > 0) {
            (address interestToken, uint256 interestCollected) = strategy
                .collectInterest(address(this), collateral.collateralAddr);
        }
    }

    /**
     * @dev allocate collateral on this contract into strategies.
     */
    function allocate() external onlyOwner nonReentrant {
        IStrategy strategy;
        collateralStruct memory collateral;
        for (uint256 y = 0; y < allCollateralAddr.length; y++) {
            collateral = collateralsInfo[allCollateralAddr[y]];
            if (collateral.defaultStrategyAddr != address(0)) {
                strategy = IStrategy(collateral.defaultStrategyAddr);
                require(strategy.supportsCollateral(collateral.collateralAddr));
                uint256 amtToAllocate = IERC20Upgradeable(
                    collateral.collateralAddr
                ).balanceOf(address(this));
                IERC20Upgradeable(collateral.collateralAddr).safeTransfer(
                    collateral.defaultStrategyAddr,
                    amtToAllocate
                );
                strategy.deposit(collateral.collateralAddr, amtToAllocate);
                emit CollateralAllocated(
                    collateral.collateralAddr,
                    collateral.defaultStrategyAddr,
                    amtToAllocate
                );
            }
        }
    }

    /**
     * @dev the value of collaterals in this contract and strategies
     */
    function totalValueLocked() public view returns (uint256 value) {
        value = totalValueInVault().add(totalValueInStrategies());
    }

    /**
     * @dev the value of collaterals in this contract
     */
    function totalValueInVault() public view returns (uint256 value) {
        for (uint256 y = 0; y < allCollateralAddr.length; y++) {
            collateralStruct memory collateral = collateralsInfo[
                allCollateralAddr[y]
            ];
            value = value.add(_valueInVault(collateral.collateralAddr));
        }
    }

    /**
     * @dev the value of collateral of _collateralAddr in this contract
     */
    function _valueInVault(address _collateralAddr)
        internal
        view
        returns (uint256 value)
    {
        collateralStruct memory collateral = collateralsInfo[_collateralAddr];
        uint256 priceColla = 10**8;
        uint256 precisionColla = 10**8;
        uint256 collateralAddrDecimal = uint256(
            ERC20Upgradeable(collateral.collateralAddr).decimals()
        );
        uint256 collateralTotalValueInVault = IERC20Upgradeable(
            collateral.collateralAddr
        ).balanceOf(address(this)).mul(priceColla).div(precisionColla);
        uint256 collateralTotalValueInVault_18 = collateralTotalValueInVault
            .mul(10**(uint256(18).sub(collateralAddrDecimal)));
        value = collateralTotalValueInVault_18;
    }

    /**
     * @dev the value of collaterals in the strategies
     */
    function totalValueInStrategies() public view returns (uint256 value) {
        for (uint256 y = 0; y < allCollateralAddr.length; y++) {
            collateralStruct memory collateral = collateralsInfo[
                allCollateralAddr[y]
            ];
            value = value.add(_valueInStrategy(collateral.collateralAddr));
        }
    }

    /**
     * @dev the value of collateral of _collateralAddr in its strategy
     */
    function _valueInStrategy(address _collateralAddr)
        internal
        view
        returns (uint256)
    {
        collateralStruct memory collateral = collateralsInfo[_collateralAddr];
        if (collateral.defaultStrategyAddr == address(0)) {
            return 0;
        }
        IStrategy strategy = IStrategy(collateral.defaultStrategyAddr);
        if (!strategy.supportsCollateral(collateral.collateralAddr)) {
            return 0;
        }
        uint256 priceColla = 10**8;
        uint256 precisionColla = 10**8;
        uint256 collateralAddrDecimal = uint256(
            ERC20Upgradeable(collateral.collateralAddr).decimals()
        );
        uint256 collateralTotalValueInStrategy = strategy
            .checkBalance(collateral.collateralAddr)
            .mul(priceColla)
            .div(precisionColla);
        uint256 collateralTotalValueInStrategy_18 = collateralTotalValueInStrategy
                .mul(10**(uint256(18).sub(collateralAddrDecimal)));
        return collateralTotalValueInStrategy_18;
    }
}
