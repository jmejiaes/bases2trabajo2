                                                                          // SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.8.0;


contract Galeria {
    // Definimos los atributos del contrato
    // ENUM para definir los estados del contrato
    enum Estado {Creado, Iniciado, CerradoInscripciones, Juzgado, Inactivo}
    // Estructura para definir las obras
    struct Work {
        address address_; // Dirección del artista
        string name_; // Nombre de la obra
        string url_; // URL de la obra
        uint rating_; // Calificación de la obra
        string comment_; // Comentario del crítico
        bool is_rating; // Si la obra ya fue calificada
    }

    // Estructura para definir los ganadores
    struct Winner {
        address address_; // Dirección del artista
        string name_; // Nombre de la obra
        uint prize_; // Premio de la obra
        string comment_; // Comentario del crítico
    }

    // Propiedades del contrato
    // Estado del contrato
    Estado public estado;
    // Dueño del contrato y crítico de arte
    address public owner;
    address public critic;
    // Valor de la bolsa
    uint public valorbolsa;
    // Lista de obras y ganadores
    Work[] public works;
    Winner[] public winners;

    // Constructor
    constructor(uint _valorbolsa) payable {
        require(_valorbolsa >= 1 ether && _valorbolsa <= 90 ether,
            "El valor de la bolsa debe ser entre 1 y 90 Ethers"
        );

        // Definimos las propiedades del contrato
        owner = msg.sender;
        valorbolsa = _valorbolsa;
        estado = Estado.Creado;
    }

    // Modificador para restringir el acceso a ciertas funciones
    modifier onlyOwner() {
        require(msg.sender == owner, "Solo el dueño puede ejecutar esta función");
        _;
    }
    modifier onlyCritic() {
        require(msg.sender == critic, "Solo el crítico puede ejecutar esta función");
        _;
    }

    // Funciones del contrato, se encargan de manejar la lógica del concurso
    function assignCritic(address _critic) public onlyOwner {
        require(estado == Estado.Creado, "El contrato debe haber sido creado");
        require(_critic != owner, "El crítico no puede ser el dueño");

        // Modificamos las propiedades del contrato
        critic = _critic;
        estado = Estado.Iniciado;
    }

    function addWork(string memory _name, string memory _url) public payable {
        require(estado == Estado.Iniciado, "El contrato debe estar en estado Iniciado");
        require(msg.sender != owner && msg.sender != critic, "El dueño y el crítico no pueden participar como artistas");
        require(works.length < 6, "El número máximo de obras es 6");

        // Verificamos que la obra no esté repetida recorriendo la lista de obras
        for (uint i = 0; i < works.length; i++) {
            require(keccak256(abi.encodePacked(works[i].url_)) != keccak256(abi.encodePacked(_url)),
                "La obra ya ha sido ingresada"
            );
        }

        // Verificamos que el artista no esté participando con otra obra
        for (uint i = 0; i < works.length; i++) {
            require(works[i].address_ != msg.sender, "El artista ya ha ingresado una obra");
        }

        // Verificamos que el costo de inscripción sea correcto
        require(msg.value == valorbolsa / 2, "El costo de inscripción debe ser la mitad del valor de la bolsa");

        // Agregamos la obra a la lista
        works.push(Work(msg.sender, _name, _url, 0, "", false));
        // Sumamos el costo de inscripción a la bolsa
        valorbolsa += msg.value;
    }

    function closeInscriptions() public onlyOwner {
        require(estado == Estado.Iniciado, "El contrato debe estar en estado Iniciado");
        require(works.length >= 4, "El número mínimo de obras es 4");

        // Modificamos el estado del contrato
        estado = Estado.CerradoInscripciones;
    }

    function getWorks() public view onlyCritic returns (Work[] memory) {
        require(estado == Estado.CerradoInscripciones, "El contrato debe estar en estado CerradoInscripciones");
        return works;
    }

    function rateWork(uint _index, uint _rating, string memory _comment) public onlyCritic {
        require(estado == Estado.CerradoInscripciones, "El contrato debe estar en estado CerradoInscripciones");
        require(_rating >= 1 && _rating <= 10, "La calificación debe ser entre 1 y 10");

        // Verificamos que la calificación no esté repetida
        for (uint i = 0; i < works.length; i++) {
            require(works[i].rating_ != _rating, "La calificación ya ha sido asignada");
        }

        if (works[_index].is_rating) {
            // Solo se puede modificar la calificación si la obra ya fue calificada
            works[_index].rating_ = _rating;
        } else {
            // Modificamos la obra
            works[_index].rating_ = _rating;
            works[_index].comment_ = _comment;
            works[_index].is_rating = true;
        }

        // La agregamos a la posición correcta ordenando la lista
        for (uint i = 0; i < works.length; i++) {
            // Ordenamos de mayor a menor calificación
            if (works[i].rating_ < works[_index].rating_) {
                Work memory temp = works[i];
                works[i] = works[_index];
                works[_index] = temp;
            }
        }
    }

    function finishRating() public onlyCritic {
        require(estado == Estado.CerradoInscripciones, "El contrato debe estar en estado CerradoInscripciones");

        // Verificamos que todas las obras hayan sido calificadas
        for (uint i = 0; i < works.length; i++) {
            require(works[i].is_rating == true, "No todas las obras han sido calificadas");
        }

        // Modificamos el estado del contrato
        estado = Estado.Juzgado;
    }

    function finishContest() public onlyOwner {
        require(estado == Estado.Juzgado, "El contrato debe estar en estado Juzgado");


        // Calculamos los premios
        uint prize1 = valorbolsa / 2;
        uint prize2 = valorbolsa / 4;
        uint prize3 = valorbolsa / 10;
        uint prize_critic = valorbolsa - prize1 - prize2 - prize3;

        // Agregamos los ganadores a la lista
        winners.push(Winner(works[0].address_, works[0].name_, prize1, works[0].comment_));
        winners.push(Winner(works[1].address_, works[1].name_, prize2, works[1].comment_));
        winners.push(Winner(works[2].address_, works[2].name_, prize3, works[2].comment_));

        // Transferimos los premios
        payable(works[0].address_).transfer(prize1);
        payable(works[1].address_).transfer(prize2);
        payable(works[2].address_).transfer(prize3);
        payable(critic).transfer(prize_critic);

        // Modificamos el estado del contrato
        estado = Estado.Inactivo;
    }

    function getWinners() public view returns (Work[] memory) {
        require(estado == Estado.Inactivo, "El contrato debe estar en estado Inactivo");
        return winners;
    }

}