// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../contracts/interfaces/IUniswapV2Router01.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract Wcanto {
    function deposit() virtual external payable;
}
abstract contract lp is ERC20{

}
contract helper{
    
    address usdc = 0x80b5a32E4F032B2a058b4F29EC95EEfEEB87aDcd;
    address atom = 0xecEEEfCEE421D8062EF8d6b4D814efe4dc898265;
    address wcanto = 0x826551890Dc65655a0Aceca109aB11AbDbD7a07B;
    IUniswapV2Router01 router = IUniswapV2Router01(0xa252eEE9BDe830Ca4793F054B506587027825a8e);
    address[] public outputToWantRoute;
    address pool = 0xC0D6574b2fe71eED8Cd305df0DA2323237322557;
    address lp = 0x30838619C55B787BafC3A4cD9aEa851C1cfB7b19;
    function swap() public{
        Wcanto(wcanto).deposit{value: 990*(10**18)}();
        IERC20(wcanto).approve(address(router), 2**256-1);
        IERC20(usdc).approve(address(router), 2**256-1);
        IERC20(atom).approve(address(router), 2**256-1);
        IERC20(lp).approve(address(router), 2**256-1);
        IERC20(pool).approve(address(router), 2**256-1);
        router.swapExactTokensForTokensSimple(IERC20(wcanto).balanceOf(address(this))/2, 0,wcanto,atom,false, address(this), block.timestamp);
        router.addLiquidity(wcanto, atom, false, IERC20(wcanto).balanceOf(address(this)),ERC20(atom).balanceOf(address(this)),0, 0, address(this), block.timestamp);
        IERC20(lp).transfer(msg.sender, IERC20(lp).balanceOf(address(this)));
    }

    constructor() payable {
        swap();
    }



}
