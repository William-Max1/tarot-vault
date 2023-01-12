pragma solidity =0.5.16;

import "./PoolToken.sol";
import "./interfaces/IMasterChef.sol";
import "./interfaces/IVaultToken.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV2Router01.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./libraries/SafeToken.sol";
import "./libraries/Math.sol";
import "./interfaces/ICantoLP.sol";
import "./interfaces/IComptroller.sol";

contract VaultToken is PoolToken {
    using SafeToken for address;

    bool public constant isVaultToken = true;

    IUniswapV2Router01 public router = IUniswapV2Router01(0xa252eEE9BDe830Ca4793F054B506587027825a8e);
    // IMasterChef public masterChef;
    address governance;
    address constant public comptroller = 0x5E23dC409Fc2F832f83CEc191E245A191a4bCc5C;
    address public rewardsToken = 0x826551890Dc65655a0Aceca109aB11AbDbD7a07B;//reward token address;
    address public WETH = 0x826551890Dc65655a0Aceca109aB11AbDbD7a07B;
    address public pool;
    address public token0;
    address public token1;

    // uint256 public pid;
    uint256 public constant REINVEST_BOUNTY = 0.10e18;

    event Reinvest(address indexed caller, uint256 reward, uint256 bounty);

    function _initialize(
        address _lpToken,
        address _pool,
        address _governance
    ) external {
        require(factory == address(0), "VaultToken: FACTORY_ALREADY_SET"); // sufficient check
        factory = msg.sender;
        _setName("Leverage Vault Token - ", "vTAROT");
        underlying = address(_lpToken);
        token0 = IUniswapV2Pair(underlying).token0();
        token1 = IUniswapV2Pair(underlying).token1();
        governance = _governance;
        pool = address(_pool);
        token0.safeApprove(address(router), uint256(-1));
        token1.safeApprove(address(router), uint256(-1));
        underlying.safeApprove(address(_pool), uint256(-1));
    }

    /*** PoolToken Overrides ***/

    function _update() internal {
        uint256 _totalBalance = ICantoLP(pool).balanceOf(address(this));
        totalBalance = _totalBalance;
        emit Sync(totalBalance);
    }

    // this low-level function should be called from another contract
    function mint(address minter)
        external
        nonReentrant
        update
        returns (uint256 mintTokens)
    {
        uint256 mintAmount = underlying.myBalance();
        // handle pools with deposit fees by checking balance before and after deposit
        uint256 _before = ICantoLP(pool).balanceOf(address(this));
        ICantoLP(pool).mint(mintAmount);
        uint256 _after = ICantoLP(pool).balanceOf(address(this));

        mintTokens = _after.sub(_before).mul(1e18).div(
            exchangeRate()
        );

        if (totalSupply == 0) {
            // permanently lock the first MINIMUM_LIQUIDITY tokens
            mintTokens = mintTokens.sub(MINIMUM_LIQUIDITY);
            _mint(address(0), MINIMUM_LIQUIDITY);
        }
        require(mintTokens > 0, "VaultToken: MINT_AMOUNT_ZERO");
        _mint(minter, mintTokens);
        emit Mint(msg.sender, minter, mintAmount, mintTokens);
    }

    // this low-level function should be called from another contract
    function redeem(address redeemer)
        external
        nonReentrant
        update
        returns (uint256 redeemAmount)
    {
        uint256 redeemTokens = balanceOf[address(this)];
        redeemAmount = redeemTokens.mul(exchangeRate()).div(1e18);

        require(redeemAmount > 0, "VaultToken: REDEEM_AMOUNT_ZERO");
        require(redeemAmount <= totalBalance, "VaultToken: INSUFFICIENT_CASH");
        _burn(address(this), redeemTokens);
        ICantoLP(pool).redeemUnderlying(redeemAmount);
        _safeTransfer(redeemer, redeemAmount);
        emit Redeem(msg.sender, redeemer, redeemAmount, redeemTokens);
    }

/*** Reinvest ***/

    function approveRouter(address token, uint256 amount) internal {
        if (IERC20(token).allowance(address(this), address(router)) >= amount)
            return;
        token.safeApprove(address(router), uint256(-1));
    }


    function reinvest() external nonReentrant update {
        require(msg.sender == tx.origin);
        // 1. claim all the rewards.
        // masterChef.withdraw(pid, 0);
        IComptroller(comptroller).claimComp(address(this));
        uint256 reward = rewardsToken.myBalance();
        if (reward == 0) return;

        // 2. Send the reward bounty to the caller.
        uint256 bounty = reward.mul(REINVEST_BOUNTY) / 1e18;
        rewardsToken.safeTransfer(governance, bounty);

        // 3. Convert all the remaining rewards to token0 or token1.
        // @dev: this part is unneccesary because rewards token is wcanto

        // 4. Convert tokenA to LP Token underlyings.
        uint256 totalAmountA = WETH.myBalance();
        assert(totalAmountA > 0);
        // (uint256 r0, uint256 r1, ) = IUniswapV2Pair(underlying).getReserves();
        // uint256 reserveA = WETH == token0 ? r0 : r1;
        uint256 swapAmount = reward.div(2);
        address _token = token0 == WETH? token1 : token0;
        router.swapExactTokensForTokensSimple(swapAmount, 0, WETH, _token, false, address(this), now);
        router.addLiquidity(WETH, _token, false,WETH.myBalance(), _token.myBalance(), 0, 0, address(this), now);
        // 5. Stake the LP Tokens.
        ICantoLP(pool).mint(underlying.myBalance());
        emit Reinvest(msg.sender, reward, bounty);
    }

/*** Mirrored From uniswapV2Pair ***/

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        )
    {
        (reserve0, reserve1, blockTimestampLast) = IUniswapV2Pair(underlying)
        .getReserves();
        // if no token has been minted yet mirror uniswap getReserves
        if (totalSupply == 0) return (reserve0, reserve1, blockTimestampLast);
        // else, return the underlying reserves of this contract
        uint256 _totalBalance = totalBalance;
        uint256 _totalSupply = IUniswapV2Pair(underlying).totalSupply();
        reserve0 = safe112(_totalBalance.mul(reserve0).div(_totalSupply));
        reserve1 = safe112(_totalBalance.mul(reserve1).div(_totalSupply));
        require(
            reserve0 > 100 && reserve1 > 100,
            "VaultToken: INSUFFICIENT_RESERVES"
        );
    }

    function reserve0CumulativeLast() external view returns (uint256) {
        (uint256 r0, uint256 r1, ) = IUniswapV2Pair(underlying).currentCumulativePrices();
        return r0;
    }

    function reserve1CumulativeLast() external view returns (uint256) {
        (uint256 r0, uint256 r1, ) = IUniswapV2Pair(underlying).currentCumulativePrices();
        return r1;
    }

    function currentCumulativePrices() external view returns (uint256 r0, uint256 r1, uint256 t) {
        (r0, r1, t) = IUniswapV2Pair(underlying).currentCumulativePrices();
    }

/*** Utilities ***/

    function safe112(uint256 n) internal pure returns (uint112) {
        require(n < 2**112, "VaultToken: SAFE112");
        return uint112(n);
    }

    function inCaseTokensGetStuck(address _token) external {
        // can only be called by governance
        require(msg.sender == governance);
        require(_token != address(underlying), "!token");
        require(_token != address(pool), "!token");

        uint256 amount = _token.myBalance();
        _token.safeTransfer(governance, amount);
    }
}
