// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.6.12;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "../../interfaces/IStrategy.sol";
/**
 * @title USDs Strategies abstract contract
 * @author Sperax Foundation
 */
abstract contract InitializableAbstractStrategy is IStrategy, Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint;

    event PTokenAdded(address indexed _asset, address _pToken);
    event PTokenRemoved(address indexed _asset, address _pToken);
    event Deposit(address indexed _asset, address _pToken, uint256 _amount);
    event Withdrawal(address indexed _asset, address _pToken, uint256 _amount);
    event InterestCollected(
        address indexed _asset,
        address _pToken,
        uint256 _amount
    );
    event RewardTokenCollected(address recipient, uint256 amount);
    event RewardTokenAddressUpdated(address _oldAddress, address _newAddress);

    // Core address for the given platform
    address public platformAddress;

    address public vaultAddress;

    // asset => pToken (Platform Specific Token Address)
    mapping(address => address) public assetToPToken;

    mapping(address => uint256) public allocatedAmt;

    // Full list of all assets supported here
    address[] internal assetsMapped;

    // Reward token address
    address public override rewardTokenAddress;

    // Reserved for future expansion
    int256[100] private _reserved;

    function _initialize(
        address _platformAddress,
        address _vaultAddress,
        address _rewardTokenAddress,
        address[] memory _assets,
        address[] memory _pTokens
    ) internal {
        OwnableUpgradeable.__Ownable_init();
        platformAddress = _platformAddress;
        vaultAddress = _vaultAddress;
        rewardTokenAddress = _rewardTokenAddress;
        uint256 assetCount = _assets.length;
        require(assetCount == _pTokens.length, "Invalid input arrays");
        for (uint256 i = 0; i < assetCount; i++) {
            _setPTokenAddress(_assets[i], _pTokens[i]);
        }
    }

    /**
     * @dev Verifies that the caller is the Vault.
     */
    modifier onlyVault() {
        require(msg.sender == vaultAddress, "Caller is not the Vault");
        _;
    }

    /**
     * @dev Verifies that the caller is the Vault or owner.
     */
    modifier onlyVaultOrOwner() {
        require(
            msg.sender == vaultAddress || msg.sender == owner(),
            "Caller is not the Vault or owner"
        );
        _;
    }

    /**
     * @dev Set the reward token address.
     * @param _rewardTokenAddress Address of the reward token
     */
    function setRewardTokenAddress(address _rewardTokenAddress)
        external
        onlyOwner
    {
        emit RewardTokenAddressUpdated(rewardTokenAddress, _rewardTokenAddress);
        rewardTokenAddress = _rewardTokenAddress;
    }

    /**
     * @dev Provide support for asset by passing its pToken address.
     *      This method can only be called by the system owner
     * @param _asset    Address for the asset
     * @param _pToken   Address for the corresponding platform token
     */
    function setPTokenAddress(address _asset, address _pToken)
        external
        onlyOwner
    {
        _setPTokenAddress(_asset, _pToken);
    }

    /**
     * @dev Remove a supported asset by passing its index.
     *      This method can only be called by the system owner
     * @param _assetIndex Index of the asset to be removed
     */
    function removePToken(uint256 _assetIndex) external onlyOwner {
        require(_assetIndex < assetsMapped.length, "Invalid index");
        address asset = assetsMapped[_assetIndex];
        address pToken = assetToPToken[asset];

        if (_assetIndex < assetsMapped.length - 1) {
            assetsMapped[_assetIndex] = assetsMapped[assetsMapped.length - 1];
        }
        assetsMapped.pop();
        assetToPToken[asset] = address(0);

        emit PTokenRemoved(asset, pToken);
    }



    /**
     * @dev Provide support for asset by passing its pToken address.
     *      Add to internal mappings and execute the platform specific,
     * abstract method `_abstractSetPToken`
     * @param _asset    Address for the asset
     * @param _pToken   Address for the corresponding platform token
     */
    function _setPTokenAddress(address _asset, address _pToken) internal {
        require(assetToPToken[_asset] == address(0), "pToken already set");
        require(
            _asset != address(0) && _pToken != address(0),
            "Invalid addresses"
        );

        assetToPToken[_asset] = _pToken;
        assetsMapped.push(_asset);

        emit PTokenAdded(_asset, _pToken);

        _abstractSetPToken(_asset, _pToken);
    }

    /**
     * @dev Check if an asset/collateral is supported.
     * @param _asset    Address of the asset
     * @return bool     Whether asset is supported
     */
    function supportsCollateral(
        address _asset
    ) external view virtual override returns (bool);

    /***************************************
                 Abstract
    ****************************************/

    /**
     * @dev approve all necs
     */
    function safeApproveAllTokens() external virtual;

    /**
     * @dev Deposit an amount of asset into the platform
     * @param _asset               Address for the asset
     * @param _amount              Units of asset to deposit
     */
    function deposit(
        address _asset,
        uint256 _amount
    ) external virtual override;

    /**
     * @dev Withdraw an amount of asset from the platform.
     * @param _recipient         Address to which the asset should be sent
     * @param _asset             Address of the asset
     * @param _amount            Units of asset to withdraw
     */
    function withdraw(
        address _recipient,
        address _asset,
        uint256 _amount
    ) external virtual override;

    /**
     * @dev Withdraw an amount of asset from the platform to vault
     * @param _asset             Address of the asset
     * @param _amount            Units of asset to withdraw
     */
    function withdrawToVault(
        address _asset,
        uint256 _amount
    ) external virtual;

    /**
     * @dev Withdraw the interest earned of asset from the platform.
     * @param _recipient         Address to which the asset should be sent
     * @param _asset             Address of the asset
     */
    function collectInterest(
        address _recipient,
        address _asset
    ) external virtual override returns(
        address interestAsset,
        uint256 interestAmt
    );

    /**
     * @dev Collect accumulated reward token and send to Vault.
     */
    function collectRewardToken() external virtual override returns(
        uint256 rewardEarned
    );



    /**
     * @dev Get the total asset value held in the platform.
     *      This includes any interest that was generated since depositing.
     * @param _asset      Address of the asset
     * @return balance    Total value of the asset in the platform
     */
    function checkBalance(address _asset)
        external
        view
        virtual
        override
        returns (uint256 balance);

    /**
     * @dev Get the amount interest earned
     * @param _asset      Address of the asset
     * @return interestEarned    The amount interest earned
     */
    function checkInterestEarned(address _asset)
        external
        view
        virtual
        override
        returns (uint256 interestEarned);

    /**
     * @dev Get the amount reward earned
     * @return rewardEarned    The amount reward earned
     */
    function checkRewardEarned()
        external
        view
        virtual
        override
        returns (uint256 rewardEarned);

    /**
     * @dev Call the necessary approvals for the Curve pool and gauge
     * @param _asset Address of the asset
     * @param _pToken Address of the corresponding platform token (i.e. 3CRV)
     */
    function _abstractSetPToken(address _asset, address _pToken)
        internal
        virtual;


}
