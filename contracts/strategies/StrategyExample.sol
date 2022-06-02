// SPDX-License-Identifier: MIT
/**
 * @title Strategy
 * @notice Investment strategy for investing stablecoins
 * @author Sperax Inc
 */
pragma solidity ^0.6.12;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
// import { ICurve2Pool } from "../../interfaces/ICurve2Pool.sol";
// import { ICurveGauge } from "../../interfaces/ICurveGauge.sol";
import { InitializableAbstractStrategy } from "./InitializableAbstractStrategy.sol";
// import { StableMath } from "../libraries/StableMath.sol";

contract StrategyExample is InitializableAbstractStrategy {
    // using StableMath for uint256;
    using SafeERC20 for IERC20;

    //uint256 internal supportedAssetIndex;

    // ICurveGauge public curveGauge;
    // ICurve2Pool public curvePool;

    /**
     * Initializer for setting up strategy internal state. This overrides the
     * InitializableAbstractStrategy initializer as Curve strategies don't fit
     * well within that abstraction.
     * @param _platformAddress Address of the Curve 2Pool
     * @param _vaultAddress Address of the vault
     * @param _rewardTokenAddress Address of CRV
     * @param _assets Addresses of supported assets. MUST be passed in the same
     *                order as returned by coins on the pool contract
     * @param _pTokens Platform Token corresponding addresses (LP token)
     */
    function initialize(
        address _platformAddress,
        address _vaultAddress,
        address _rewardTokenAddress,
        address[] calldata _assets,
        address[] calldata _pTokens
        //uint256 _supportedAssetIndex,
    ) external initializer {
        //require(_supportedAssetIndex < _assets.length, " ");
        InitializableAbstractStrategy._initialize(
            _platformAddress,
            _vaultAddress,
            _rewardTokenAddress,
            _assets,
            _pTokens
        );
        // curvePool = ICurve2Pool(platformAddress);
        // curveGauge = ICurveGauge(_crvGaugeAddress);
        //supportedAssetIndex = _supportedAssetIndex;

    }

    // /**
    //  * @dev change to a new lpAssetThreshold
    //  * @dev lpAssetThreshold should be set to the minimum number
    //         of totalPTokens such that curvePool.calc_withdraw_one_coin does not
    //         revert
    //  * @param _lpAssetThreshold new lpAssetThreshold
    //  */
    // function changeThreshold(uint256 _lpAssetThreshold) external onlyOwner {
    //     lpAssetThreshold = _lpAssetThreshold;
    //     emit ThresholdChanged(lpAssetThreshold);
    // }


    /**
     * @dev Check if an asset/collateral is supported.
     * @param _asset    Address of the asset
     * @return bool     Whether asset is supported
     */
    function supportsCollateral(
        address _asset
    ) public view override returns (bool) {
        if (assetToPToken[_asset] != address(0)
            // && _getPoolCoinIndex(_asset) == supportedAssetIndex
        ) {
                return true;
            }
        else {
            return false;
        }
    }

    /**
     * @dev Approve the spending of all assets by their corresponding pool tokens,
     *      if for some reason is it necessary.
     */
    function safeApproveAllTokens() override onlyOwner external {
        //TO-DO
    }

    /**
     * @dev Deposit asset into the Curve 2Pool
     * @param _asset Address of asset to deposit
     * @param _amount Amount of asset to deposit
     */
    function deposit(address _asset, uint256 _amount)
        external
        override
        onlyVault
        nonReentrant
    {
        require(supportsCollateral(_asset), "Unsupported collateral");
        require(_amount > 0, "Must deposit something");
        //TO-DO:
        emit Deposit(_asset, address(assetToPToken[_asset]), _amount);
    }

    function withdraw(
        address _recipient,
        address _asset,
        uint256 _amount
    ) external override onlyVault nonReentrant {
        _withdraw(_recipient, _asset, _amount);
    }

    /**
     * @dev Withdraw asset from Curve 2Pool
     * @param _asset Address of asset to withdraw
     * @param _amount Amount of asset to withdraw
     */
    function withdrawToVault(
        address _asset,
        uint256 _amount
    ) external override onlyOwner nonReentrant {
        _withdraw(vaultAddress, _asset, _amount);
    }

    /**
     * @dev Collect interest earned from 2Pool
     * @param _recipient Address to receive withdrawn asset
     * @param _asset Asset type deposited into this strategy contract
     */
    function collectInterest(
        address _recipient,
        address _asset
    ) external override onlyVault nonReentrant returns (
        address interestAsset,
        uint256 interestEarned
    ) {
        //TO-DO:
    }

    /**
     * @dev Collect accumulated CRV and send to Vault.
     */
    function collectRewardToken() external override onlyVault nonReentrant returns (
        uint256 rewardEarned
    )
    {
        //TO-DO:
    }



    /**
     * @dev Get the total asset value held in the platform
     * @param _asset      Address of the asset
     * @return balance    Total amount of the asset in the platform
     */
    function checkBalance(address _asset)
        public
        override
        view
        returns (uint256 balance)
    {
        require(supportsCollateral(_asset), "Unsupported collateral");
        //TO-DO:
    }

    /**
     * @dev Get the amount of asset/collateral earned as interest
     * @param _asset  Address of the asset
     * @return interestEarned
               The amount of asset/collateral earned as interest
     */
    function checkInterestEarned(address _asset)
        public
        view
        override
        returns (uint256)
    {
        require(supportsCollateral(_asset), "Unsupported collateral");
        uint256 balance = checkBalance(_asset);
        if (balance > allocatedAmt[_asset]) {
            return balance.sub(allocatedAmt[_asset]);
        } else {
            return 0;
        }
    }

    /**
     * @dev Get the amount of asset/collateral earned as interest
     * @return interestEarned
               The amount of asset/collateral earned as interest
     */
    function checkRewardEarned()
        public
        view
        override
        returns (uint256)
    {
        //TO-DO:
        return 0;
    }

    /**
     * @dev Withdraw asset from Curve 2Pool
     * @param _recipient Address to receive withdrawn asset
     * @param _asset Address of asset to withdraw
     * @param _amount Amount of asset to withdraw
     */
    function _withdraw(
        address _recipient,
        address _asset,
        uint256 _amount
    ) internal {
        require(_recipient != address(0), "Invalid recipient");
        //require(supportsCollateral(_asset), "Unsupported collateral");
        require(_amount > 0, "Invalid amount");
        //TO-DO:
    }

    /**
     * @dev Call the necessary approvals for the Curve pool and gauge
     * @param _asset Address of the asset
     * @param _pToken Address of the corresponding platform token (i.e. 2CRV)
     */
    function _abstractSetPToken(address _asset, address _pToken) override internal {
        IERC20 asset = IERC20(_asset);
        IERC20 pToken = IERC20(_pToken);
        // To change
        asset.safeApprove(platformAddress, uint256(-1));
        pToken.safeApprove(platformAddress, uint256(-1));
    }

    // /**
    //  * @dev Calculate the total platform token balance (i.e. 2CRV) that exist in
    //  * this contract or is staked in the Gauge (or in other words, the total
    //  * amount platform tokens we own).
    //  */
    // function _getTotalPTokens()
    //     internal
    //     view
    //     returns (
    //         uint256 contractPTokens,
    //         uint256 gaugePTokens,
    //         uint256 totalPTokens
    //     )
    // {
    //     contractPTokens = IERC20(assetToPToken[assetsMapped[0]]).balanceOf(
    //         address(this)
    //     );
    //     gaugePTokens = curveGauge.balanceOf(address(this));
    //     totalPTokens = contractPTokens.add(gaugePTokens);
    // }

    /**
     * @dev Get the index of the coin in 2Pool
     */
    function _getPoolCoinIndex(address _asset) internal view returns (uint256) {
        for (uint256 i = 0; i < 2; i++) {
            if (assetsMapped[i] == _asset) return i;
        }
        revert("Unsupported collateral");
    }
}
