// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;
interface IComptroller{
    function claimComp(address holder) external;
    function pendingComptrollerImplementation() external view returns(address);
}