// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract nffMain{
    /*__________________________________Shared variabes______________________________________ */
    address public oracleAddr;
    address public owner;
    /*__________________________________From Orignal NFT Bank_________________________________ */
    uint256 public minDeposit;
    uint256 public nftFloorPrice; //temporary
    uint256 public nftLiquidationPrice;
    uint256 public discountFactor;
    //Use to store user's eth balance
    mapping(address => uint256) addressToBalances;
    //Use to check user's address existance
    mapping(address => bool) userChecker;
    //Use to check if an NFT colelction is supported
    mapping(address => bool) supportedNft;
    //Use to store key (address) of people who deposit ETH
    address[] private ethDepositorList;
    //For saving supported NFT (Can be implemented by saving every data from liquidated NFT)
    address[] private supportedNftList;
    /*__________________________________From NFT Loan________________________________________ */
    /*
    * Check if a loan is due every day at 00:00, if current time > due time, the loan is defaulted
    * Future development: Implement BokkyPooBahsDateTimeLibrary https://github.com/bokkypoobah/BokkyPooBahsDateTimeLibrary
    */
    //defaultRate = number of times that the customer can pay their loan later
    uint256 public defaultRate;
    uint256 public interstRate;
    //penatly for loan with default count > 0
    uint256 public penaltyRate;
    uint256 public downPayment; //to be implemented
    //The Loan structure InLoan = instalment Loan
    //The Nft token uniquely define the Loan
    struct InLoan{
        address loanOwner;
        uint256 loanAmount;
        uint256 outstandBalance;
        uint256 startTime;
        uint256 dueTime;
        uint256 defaultCount;
        NftToken nft;
    }
    struct NftToken{
        address nftContractAddr;
        uint256 tokenId;
    }
    //For mapping between owner and thier loans
    mapping(address => InLoan[]) addressToInLoans;
    //For mapping between customers and the number of loans
    mapping(address => uint256) customAddrToNumLoans;
    //For mapping between NFT contract address and floor price
    mapping(address => uint256) nftToFloorPrice;
    //For tracking customers, no dups in this array
    address[] public customerList;
    //For tracking which nft is in a loan, no dups in this array
    NftToken[] public nftInLoan;
    //For storing a list of Loan to be removed can be private
    InLoan[] public loanRemoveList;
    //For storing a list of avalible NFT
    NftToken[] public avalibleNft;

    using SafeMath for uint256;

    constructor(){
        owner = msg.sender;
        //Below from NFT Bank
        minDeposit = 0.5 ether;
        //initial discount factor
        discountFactor = 70;
        
        //Below from NFT Loan
        downPayment = 1 ether;
        //initial defaultRate
        defaultRate = 3;
        //initial interstRate in percent
        interstRate = 5;
        //initial penatlyRate in percent
        penaltyRate = 5;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Sorry you are not the owner");
        _;
    }

/*_____________________________Below from NFT Banking____________________________ */

/*__________________________________ETH Banking_________________________________ */

    //User deposite ETH through this function
    function depositETH() external payable{
        require(msg.value >= minDeposit, "minimum deposit requirement not met");
        addressToBalances[msg.sender] += msg.value;
        userChecker[msg.sender] = true;
        if(isUserInList(msg.sender) == false){
            ethDepositorList.push(msg.sender);
        }
    }

    //called by ChainLink Keepers Time-based Trigger
    function paidInterest() private{
        
    }

    //User withdrawETH through this function
    function withdrawETH(uint256 amount) external payable {
        require (addressToBalances[msg.sender] >= amount);
        addressToBalances[msg.sender] -= amount;
        if(addressToBalances[msg.sender] == 0){
            for(uint256 i = 0; i < ethDepositorList.length; i++){
                if(ethDepositorList[i] == msg.sender){
                    ethDepositorList[i] = ethDepositorList[ethDepositorList.length - 1];
                    ethDepositorList.pop();
                }
            }
        }
        payable(msg.sender).transfer(amount);
    }

/*__________________________________NFT Liquidating________________________________ */

    function liquidateNFT(address contractAddr, uint256 tokenId) external payable{
        //First check if the NFT collection is verified on our platform
        require(supportedNft[contractAddr], "Your NFT collection is not verified");
        ERC721 Nft = ERC721(contractAddr);
        //Second check if the user approved this contract to use the NFT token
        require(Nft.isApprovedForAll(msg.sender, address(this)), "This contract must be approved to use your NFT");
        //Third check if the user own the NFT token
        require(Nft.ownerOf(tokenId) == msg.sender, "caller must own the NFT"); //no need
        //All statisfied then call transfer
        Nft.transferFrom(msg.sender, address(this), tokenId);
        //Set condition on amout paid later
        payable(msg.sender).transfer(nftLiquidationPrice);
    }

/*__________________________________Getter_____________________________________ */
    
    //Check Individual balance for GUI
    function getUserBalance(address addr) public view returns(uint256){
        return addressToBalances[addr];
    }

    //Check all user list for debug
    function getethDepositorList() public view returns(address[] memory){
        return(ethDepositorList);
    }

    function getsupportedNftList() public view returns(address[] memory){
        return(supportedNftList);
    }

    function getsupportedNftMap(address contractAddr) public view returns(bool){
        return(supportedNft[contractAddr]);
    }

/*__________________________________Setter_____________________________________ */
    
    //Add a collection to the supportedNFT array (onlyOwner)
    function addSuppCollection(address contractAddr) external onlyOwner{
        supportedNft[contractAddr] = true;
        supportedNftList.push(contractAddr);
    }

    //Set minimum deposit amount (onlyOwner)
    // Please use https://eth-converter.com/ to see convertion rate
    function setMinDeposit(uint256 amountInWei) external onlyOwner{
        minDeposit = amountInWei;
    }

    // Set the orcacle address (onlyOwner)
    // Should be called using Constructor, Deploy oracle first then this contract to get the oracle contract address
    function setOracleAddr(address contractAddr) external onlyOwner{
        oracleAddr = contractAddr;
    }

    //only allow the oracle contract to call this
    function setAssetPrice(uint256 amount) external{
        require(msg.sender == oracleAddr, "Only the orcacle contract can call this function");
        nftFloorPrice = amount;
        nftLiquidationPrice = amount.mul(discountFactor).div(100);
    }

    /*
    * Set a discount factor in terms of percentage (Used in setLiquidationPrice)
    * percentage = 80 implies a 80% discount on the OpenSea floor price
    * if OpenSea floor Price = 10e percentage = 80 implies that the bank will only
    * pay 8e for the NFT
    * Only take integer no floating point please
    */
    function setDiscountFactor(uint256 percentage) external onlyOwner{
        discountFactor = percentage;
    }

/*__________________________________Other_____________________________________ */
    
    //Check if a user is in this list 
    function isUserInList(address input) private view returns(bool){
        for (uint256 i = 0;  i < ethDepositorList.length; i++){
            if (ethDepositorList[i] == input){
                return true;
            }
        }
        return false;
    }

/*___________________________Below from NFT Loaning____________________________ */

/*__________________________________NFT Loaning_________________________________ */
    //For starting a nft instalment loan. block.timestamp gives you the current time in unix timestamp
    //Please use https://www.unixtimestamp.com/ for conversion
    //LoanAmount set by the oracle ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    function startLoan(address nftContractAddr, uint256 loanAmount, uint256 dueTime, uint256 tokenId) external payable{
        require(msg.value >= downPayment, "down payment requirement not met");
        require(msg.value < loanAmount, "Please consider direct buying instead of loan");
        NftToken memory token = NftToken(nftContractAddr, tokenId);
        require(checkNftBalance(token), "The contract doesnt own this NFT");
        require(!checkNftInList(token), "The NFT you selected is on others instalment loan");
        //Create the loan, msg.value = down payment
        InLoan memory temp = InLoan(msg.sender, loanAmount, 
        loanAmount - msg.value, block.timestamp, dueTime, 0, token);
        //Append the loan into the array inside the map
        addressToInLoans[msg.sender].push(temp);
        //Append the sender address to the customer list if he is a new customer
        if(!checkCustomerInList(msg.sender)){
            customerList.push(msg.sender);
        }
        //Increase the customers number of loan
        customAddrToNumLoans[msg.sender] += 1;
        //Append the nft to the loaning list
        nftInLoan.push(token);
    }

    //For User to call for repaying the loan
    function repayLoan(address nftContractAddr, uint256 tokenId) external payable{
        NftToken memory token = NftToken(nftContractAddr, tokenId);
        //Check if the loan exist in the beginning
        require(checkLoanExist(msg.sender,token), "No such loan, please check the NFT contract or tokenId");
        //A for loop to locate the loan matching the NFT contractaddr and tokenID
        for(uint256 i = 0; i<addressToInLoans[msg.sender].length; i++){
            if (addressToInLoans[msg.sender][i].nft.nftContractAddr == nftContractAddr && 
                addressToInLoans[msg.sender][i].nft.tokenId == tokenId){
                require(msg.value <= addressToInLoans[msg.sender][i].outstandBalance, "You have overpaid the loan");
                //Decrease the outstanding balance of the matching loan
                addressToInLoans[msg.sender][i].outstandBalance -= msg.value;
                //Check if the loan is fully paid
                if (addressToInLoans[msg.sender][i].outstandBalance <= 0){
                    //Transfer the nft
                    transferNft(addressToInLoans[msg.sender][i].nft, msg.sender);
                    //Remove the loan
                    removePaidLoan(msg.sender,token);
                }
            }
        }
    }

    function buyNFT(address nftContractAddr, uint256 tokenId) external payable{
        NftToken memory token = NftToken(nftContractAddr, tokenId);
        require(supportedNft[nftContractAddr], "Your NFT collection is not verified");
        require(checkNftBalance(token), "The contract doesnt own this NFT");
        require(!checkNftInList(token), "The NFT you selected is on others instalment loan");
        require(msg.value == nftFloorPrice, "You pay too much or too less");
        transferNft(token,msg.sender);
    }

    //Only callable by the contract to remove the paid loan from the addressToInLoans mapping InLoan[] aray
    function removePaidLoan(address addr, NftToken memory token) private{
        //A for loop to locate the loan matching the the NFT contractaddr and tokenID
        for(uint256 i = 0; i<addressToInLoans[addr].length; i++){
            //Check if the loan exist
            if (addressToInLoans[addr][i].nft.tokenId == token.tokenId &&
                addressToInLoans[addr][i].nft.nftContractAddr == token.nftContractAddr){
                //Set the matching loan to the last loan of the array
                addressToInLoans[addr][i] = addressToInLoans[addr][addressToInLoans[addr].length - 1];
                //pops the array to get rig of the last item
                addressToInLoans[addr].pop();
            }
        }
        //remove the nft from the NFT in loan list
        removeNftList(token);
        //Decrease the number of loans a customer holds
        customAddrToNumLoans[addr] -= 1;
        if (customAddrToNumLoans[addr] <= 0){
            //remove customer from the customerList if they dont have any loan
            removeCustomerList(addr);
        }
    }

    //Check which loan is due and remove those loan which doesn't fully paid
    //only callable by the oracle
    function callDueLoan() public{
        // require(msg.sender == oracleAddr, "Only the orcacle contract can call this function");
        for (uint256 i=0; i < customerList.length; i++){
            for(uint256 j=0; j < addressToInLoans[customerList[i]].length; j++){
                if(addressToInLoans[customerList[i]][j].dueTime < block.timestamp){
                    if(addressToInLoans[customerList[i]][j].defaultCount >= defaultRate){
                        loanRemoveList.push(addressToInLoans[customerList[i]][j]);
                    }
                    else{
                        addressToInLoans[customerList[i]][j].defaultCount++;
                    }
                }
            }
        }
        removeDefaultLoan(loanRemoveList);
        delete loanRemoveList;
    }

    //Change interest on every NFT based on defaultRate
    //only allow the oracle contract to call this
    function chargeInterest() public{
        // require(msg.sender == oracleAddr, "Only the orcacle contract can call this function");
        for (uint256 i=0; i < customerList.length; i++){
            for(uint256 j=0; j < addressToInLoans[customerList[i]].length; j++){
                if(addressToInLoans[customerList[i]][j].defaultCount == 0){
                    addressToInLoans[customerList[i]][j].outstandBalance += 
                    addressToInLoans[customerList[i]][j].outstandBalance.mul(interstRate).div(100);
                }
                else if(addressToInLoans[customerList[i]][j].defaultCount == 1){
                    addressToInLoans[customerList[i]][j].outstandBalance += 
                    addressToInLoans[customerList[i]][j].outstandBalance.mul(interstRate.mul(2)).div(100);
                }
                else if(addressToInLoans[customerList[i]][j].defaultCount == 2){
                    addressToInLoans[customerList[i]][j].outstandBalance += 
                    addressToInLoans[customerList[i]][j].outstandBalance.mul(interstRate.mul(3)).div(100);
                }
                else if(addressToInLoans[customerList[i]][j].defaultCount == 3){
                    addressToInLoans[customerList[i]][j].outstandBalance += 
                    addressToInLoans[customerList[i]][j].outstandBalance.mul(interstRate.mul(4)).div(100);
                }
            }
        }
    }

    /*__________________________________Getter_____________________________________ */

    //Return an array of InLoans of a user
    function getAllUserLoan(address addr) public view returns(InLoan[] memory){
        return addressToInLoans[addr];
    }

    function getUserNumLoan(address addr) public view returns(uint256){
        return customAddrToNumLoans[addr];
    }

    /*__________________________________Setter_____________________________________ */

    //Only called by the contract
    function removeNftList(NftToken memory token) private{
        for(uint256 i = 0; i<nftInLoan.length; i++){
            //Check if the nft in the list or not
            if (nftInLoan[i].nftContractAddr == token.nftContractAddr 
            && nftInLoan[i].tokenId == token.tokenId){
                //Set the matching nft to the last nft of the array
                nftInLoan[i] = nftInLoan[nftInLoan.length -1];
                //pops the array to get rig of the last item
                nftInLoan.pop();
            }
        }
    }

    //Only called by the contract
    //Remove a customer from the customer list
    function removeCustomerList(address addr) private{
        for(uint256 i = 0; i <customerList.length; i++){
            if(customerList[i] == addr){
                customerList[i] = customerList[customerList.length-1];
                customerList.pop();
            }
        }
    }

    function setDefaultRate(uint256 rate) public onlyOwner{
        defaultRate = rate;
    }

    //Remove all defaulted loan from all the array and mapping
    function removeDefaultLoan(InLoan[] memory removeList) private{
        for(uint256 i=0; i < removeList.length; i++){
            //Search the Loan index from addressToInLoans
            for (uint256 j=0; j < addressToInLoans[removeList[i].loanOwner].length; j++){
                if(addressToInLoans[removeList[i].loanOwner][j].nft.nftContractAddr == removeList[i].nft.nftContractAddr && 
                   addressToInLoans[removeList[i].loanOwner][j].nft.tokenId == removeList[i].nft.tokenId){
                    
                    //remove the loan from addressToInLoans
                    addressToInLoans[removeList[i].loanOwner][j] = 
                    addressToInLoans[removeList[i].loanOwner][addressToInLoans[removeList[i].loanOwner].length -1];
                    addressToInLoans[removeList[i].loanOwner].pop();
                    
                    //remove the loan from nftInLoan list so that it will be avalible for loaning out again
                    removeNftList(removeList[i].nft);
                    //Decrease the customers number of loans
                    customAddrToNumLoans[removeList[i].loanOwner] -= 1;

                    if (customAddrToNumLoans[removeList[i].loanOwner] <= 0){
                    //remove customer from the customerList if they dont have any loan
                        removeCustomerList(removeList[i].loanOwner);
                    }           
                }
            }

        }
    }

    /*__________________________________Checker_____________________________________ */

    //Return true if a loan is fully repaid, false otherwise
    //For future use just in case, no use right now
    function checkLoanPaid(address addr, NftToken memory token) public view returns(bool){
        for(uint256 i = 0; i<addressToInLoans[addr].length; i++){
            if(addressToInLoans[addr][i].nft.tokenId == token.tokenId &&
               addressToInLoans[addr][i].nft.nftContractAddr == token.nftContractAddr && 
               addressToInLoans[addr][i].outstandBalance <= 0){
                return true;
            }
        }
        return false;
    }

    //Check if a loan exist
    function checkLoanExist(address addr, NftToken memory token) public view returns(bool){
        for(uint256 i = 0; i<addressToInLoans[addr].length; i++){
            if(addressToInLoans[addr][i].nft.tokenId == token.tokenId &&
               addressToInLoans[addr][i].nft.nftContractAddr == token.nftContractAddr){
                return true;
            }
        }
        return false;
    }

    //Check if the nft is in the loan list
    function checkNftInList(NftToken memory token) public view returns(bool){
        for(uint256 i = 0; i<nftInLoan.length; i++){
            //Check if the nft in the list or not
            if (nftInLoan[i].nftContractAddr == token.nftContractAddr && 
                nftInLoan[i].tokenId == token.tokenId){
                return true;
            }
        }
        return false;
    }

    //Check if the this contract owns the nft
    function checkNftBalance(NftToken memory token) public view returns(bool){
        ERC721 Nft = ERC721(token.nftContractAddr);
        if (Nft.ownerOf(token.tokenId) == address(this)){
            return true;
        }
        else{
            return false;
        }
    }

    //For degugging
    function checkCustomerInList(address addr) public view returns(bool){
        for(uint256 i =0; i < customerList.length; i++){
            if(customerList[i] == addr){
                return true;
            }
        }
        return false;
    }

    /*__________________________________Other_____________________________________ */

    //Transfer the nft to the customer, only called by the contract
    function transferNft(NftToken memory token, address transferTo) private {
        ERC721 Nft = ERC721(token.nftContractAddr);
        Nft.transferFrom(address(this), transferTo, token.tokenId);
    }

    //Widthdraw All ETH for testnet purpose only
    function withdraw() public onlyOwner {
        Address.sendValue(payable(msg.sender), address(this).balance);
    }

}