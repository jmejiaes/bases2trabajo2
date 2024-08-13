// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.8.0;
pragma abicoder v2;

contract Gallery {
    // Define the contract attributes
    enum State {Created, Started, RegistrationClosed, Judged, Inactive}

    struct Work {
        address artist; // Artist's address
        string name; // Name of the work
        string url; // URL of the work
        uint rating; // Rating of the work
        string comment; // Critic's comment
        bool rated; // Whether the work has been rated
    }

    struct Winner {
        address artist; // Artist's address
        string name; // Name of the work
        uint prize; // Prize for the work
        string comment; // Critic's comment
    }

    State public state; // Contract state
    address public owner; // Contract owner
    address public critic; // Art critic
    uint public prizePool; // Prize pool amount
    Work[] public works; // List of works
    Winner[] public winners; // List of winners

    constructor(uint _prizePool) payable {
        require(_prizePool >= 1 ether && _prizePool <= 90 ether,
            "The prize pool must be between 1 and 90 Ethers"
        );
        owner = msg.sender;
        prizePool = _prizePool;
        state = State.Created;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can execute this function");
        _;
    }

    modifier onlyCritic() {
        require(msg.sender == critic, "Only the critic can execute this function");
        _;
    }

    function assignCritic(address _critic) public onlyOwner {
        require(state == State.Created, "The contract must be in Created state");
        require(_critic != owner, "The critic cannot be the owner");
        critic = _critic;
        state = State.Started;
    }

    function addWork(string memory _name, string memory _url) public payable {
        require(state == State.Started, "The contract must be in Started state");
        require(msg.sender != owner && msg.sender != critic, "The owner and the critic cannot participate as artists");
        require(works.length < 6, "The maximum number of works is 6");

        // Check that the work is not already added
        for (uint i = 0; i < works.length; i++) {
            require(keccak256(abi.encodePacked(works[i].url)) != keccak256(abi.encodePacked(_url)),
                "The work has already been added"
            );
        }

        // Check that the artist is not already participating with another work
        for (uint i = 0; i < works.length; i++) {
            require(works[i].artist != msg.sender, "The artist has already submitted a work");
        }

        // Check that the registration fee is correct
        require(msg.value == prizePool / 2, "The registration fee must be half of the prize pool");

        // Add the work to the list
        works.push(Work(msg.sender, _name, _url, 0, "", false));
        prizePool += msg.value; // Add the registration fee to the prize pool
    }

    function closeRegistrations() public onlyOwner {
        require(state == State.Started, "The contract must be in Started state");
        require(works.length >= 4, "The minimum number of works is 4");
        state = State.RegistrationClosed;
    }

    function getWorks() public view onlyCritic returns (Work[] memory) {
        require(state == State.RegistrationClosed, "The contract must be in RegistrationClosed state");
        return works;
    }

    function rateWork(uint _index, uint _rating, string memory _comment) public onlyCritic {
        require(state == State.RegistrationClosed, "The contract must be in RegistrationClosed state");
        require(_rating >= 1 && _rating <= 10, "The rating must be between 1 and 10");

        Work storage work = works[_index];

        if (work.rated) {
            work.rating = _rating; // Modify rating if the work has already been rated
        } else {
            work.rating = _rating;
            work.comment = _comment;
            work.rated = true;
        }

        // Sort the list of works by rating from highest to lowest
        for (uint i = _index; i > 0 && works[i].rating > works[i - 1].rating; i--) {
            Work memory temp = works[i];
            works[i] = works[i - 1];
            works[i - 1] = temp;
        }
    }

    function finishRating() public onlyCritic {
        require(state == State.RegistrationClosed, "The contract must be in RegistrationClosed state");

        // Check that all works have been rated
        for (uint i = 0; i < works.length; i++) {
            require(works[i].rated == true, "Not all works have been rated");
        }

        state = State.Judged;
    }

    function finishContest() public onlyOwner {
        require(state == State.Judged, "The contract must be in Judged state");

        // Calculate prizes
        uint prize1 = prizePool / 2;
        uint prize2 = prizePool / 4;
        uint prize3 = prizePool / 10;
        uint criticPrize = prizePool - prize1 - prize2 - prize3;

        // Add winners to the list
        winners.push(Winner(works[0].artist, works[0].name, prize1, works[0].comment));
        winners.push(Winner(works[1].artist, works[1].name, prize2, works[1].comment));
        winners.push(Winner(works[2].artist, works[2].name, prize3, works[2].comment));

        // Transfer prizes
        payable(works[0].artist).transfer(prize1);
        payable(works[1].artist).transfer(prize2);
        payable(works[2].artist).transfer(prize3);
        payable(critic).transfer(criticPrize);

        state = State.Inactive;
    }

    function getWinners() public view returns (Winner[] memory) {
        require(state == State.Inactive, "The contract must be in Inactive state");
        return winners;
    }
}
