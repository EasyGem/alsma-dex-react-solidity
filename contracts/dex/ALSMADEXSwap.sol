// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "./ALSMADEXComission.sol";
import "hardhat/console.sol";

contract ALSMADEXSwap is ALSMADEXComission {
    // events
    event Swap();

    // external

    function swap(
        address fromTokenAddress,
        address toTokenAddress,
        uint256 fromAmount
    ) external {
        (
            uint256 fromTokenIndex,
            bool isFromTokenAdded
        ) = _getTokenIndexByAddress(fromTokenAddress);
        (uint256 toTokenIndex, bool isToTokenAdded) = _getTokenIndexByAddress(
            toTokenAddress
        );

        require(isFromTokenAdded, "From token does not exist");
        require(isToTokenAdded, "To token does not exist");

        ERC20 tokenContract = ERC20(fromTokenAddress);

        require(fromAmount > 0, "Stake amount must be greater than 0");
        require(
            _getBalanceOfToken(fromTokenAddress, msg.sender) >= fromAmount,
            "Not enough tokens on balance"
        );
        require(
            tokenContract.allowance(msg.sender, address(this)) >= fromAmount,
            "Not enough approved tokens"
        );

        // simplified for now (1:1 ratio for every coin)
        uint256 toAmount = fromAmount;

        // uint256 toAmount =
        // require(
        //             _getTotalSupply(toTokenAddress) >= targetAmount,
        //             "Not enough tokens in supply"
        //         );

        _distributeComission(toTokenAddress, toAmount);
    }

    // internal

    /**
     * Distributes comission among stakers in tokenAddressToStakerAddressList[tokenAddress].
     * Share depends on «staked» value from tokenToStakerToStakeDetails.
     * Updates «earned» values.
     */
    function _distributeComission(address tokenAddress, uint256 amount)
        internal
    {
        uint256 totalSupply = _getTotalSupply(tokenAddress);
        uint256 comission = _calculateComissionRateForToken(tokenAddress);
        uint256 comissionShare = (comission * amount) / 10**8; // divide by comission decimals

        uint256 residualShare = comissionShare;
        comissionShare -= comissionShare / 10; // 10% belongs to DEX

        /**
         * Distribute among stakers based on the size of their stake
         * compared to the totalSupply
         */
        for (
            uint256 i = 0;
            i < tokenAddressToStakerAddressList[tokenAddress].length;
            i++
        ) {
            address stakerAddress = tokenAddressToStakerAddressList[
                tokenAddress
            ][i];
            StakeDetails storage stakerDetails = tokenToStakerToStakeDetails[
                tokenAddress
            ][stakerAddress];
            uint256 stakerRelativeShare = (stakerDetails.staked * 10**8) /
                totalSupply; // percent with 8 decimals
            uint256 stakerShare = (comissionShare * stakerRelativeShare) /
                10**8;

            stakerDetails.earned += stakerShare;

            residualShare -= stakerShare;
        }

        /**
         * There can be a «left over» after distribution.
         * Saving it to the treasury as well.
         */
        _sendTokensToTreasury(tokenAddress, residualShare);

        emit Swap();
    }
}
