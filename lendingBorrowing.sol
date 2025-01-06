// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// basic contract for lending borrowing protocol
// put ETH as colletral 
// used for borrowig other erc20 tokens
// borrower will pay 1.2X the value of the tokens he borrowed

interface IERC20{
    function transfer(address to, uint amount)external returns (bool);
    function transferFrom(address from , address to, uint amount)external  returns (bool);
    function balanceOf(address user)external returns (uint);
}

contract BasicLending{
    address Owner;
    IERC20 public token;

    uint poolAmount;
    uint EthPool;
    uint public ColleteralRate =120;
    uint fees = 2;

    uint TotalFee;

    constructor(address _token){
        Owner = msg.sender;
        token = IERC20(_token);
        
    }

    mapping (address => uint) public Borrowed;
    mapping (address => uint) public colleteralBalance;
    mapping (address => uint) public Balance;

    // MODIFIERS
    modifier onlyOwenr(){
        require(msg.sender == Owner);
        _;
    }
    // FUNCTIONS

    // LIQUIDITY OWNER FUNCTIONS
    function depositeInPool(uint amount)public payable {
        require(amount <= token.balanceOf(msg.sender));
        poolAmount += amount;
        require(token.transferFrom(msg.sender, address(this), amount));
        Balance[msg.sender] += amount;
        
        
    }

    function withdrawFromPool(uint amount) public {
        require(Balance[msg.sender] >= amount,"Insufficient balance");
        require(poolAmount >= amount);
        require(amount > 0,"Invalic Entry");

        Balance[msg.sender] -= amount;
        poolAmount -= amount;
        token.transfer(msg.sender, amount);
    }

    

    
    // COLLATERAL FUNCTIONS
    function calculateColletaral(uint BorrowAmount)internal view returns (uint) {
        return  (BorrowAmount * ColleteralRate) /100;
        
    }

    function borrowAssets(uint amount) public payable {
        uint colleteral = calculateColletaral(amount);

        require(msg.value >= colleteral,"Insufficient balance");
        require(poolAmount >= amount,"Not enought amount in pool");
        require(amount > 0,"Invalid entry");

        Borrowed[msg.sender] += amount;
        poolAmount -= amount;

        uint FeeCut = (msg.value * fees)/100;
        uint COlleteralAfterFee = msg.value - FeeCut;
        colleteralBalance[msg.sender] += COlleteralAfterFee;

        TotalFee += FeeCut;

        EthPool += COlleteralAfterFee;
        token.transfer(msg.sender, amount);
    }

    function repay(uint amount)public {
        require(amount > 0,"Invalid");
        require(amount <= Borrowed[msg.sender],"Exceeds borrowed amount");

        token.transfer(address(this), amount);
        poolAmount += amount;

        uint repayAmount = (colleteralBalance[msg.sender] * amount)/ Borrowed[msg.sender];

        EthPool -= repayAmount;
        payable (msg.sender).transfer(repayAmount);
        
    }

    function claimFee()public onlyOwenr{
        uint amount = TotalFee;
        require(amount> 0,"Nothing pending");
        payable(Owner).transfer(amount);
    } 
    
    function getHealthFactor(address borrower) public view returns(uint){
        uint collateralValue = colleteralBalance[borrower]; 
        uint borrowedValue = Borrowed[borrower];

        if (borrowedValue == 0){
            return type(uint).max;
        }

        uint requiredCollateral = calculateColletaral(borrowedValue);
        return (collateralValue * 1e18) / requiredCollateral;
    }

    function liquidate(address borrower)public{
        uint healthFactor = getHealthFactor(borrower);
        require(healthFactor < 1e18,"No further liquidation needed");

        uint collateralSeizable = colleteralBalance[borrower];
        uint debt = Borrowed[borrower];

        collateralSeizable = 0;
        debt  = 0;

        EthPool -= collateralSeizable;
        payable (msg.sender).transfer(collateralSeizable);

        
    }

     

}
