// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

interface IERC20 {
    error ERC20_TransferToSelf();
    error ERC20_TransferToZeroAddress();
    error ERC20_TransferFromZeroAddress();
    error ERC20_InsufficientBalance();
    error ERC20_OwnerIsSpender();
    error ERC20_OwnerIsZeroAddress();
    error ERC20_SpenderIsZeroAddress();
    error ERC20_InsufficientAllowance();

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}