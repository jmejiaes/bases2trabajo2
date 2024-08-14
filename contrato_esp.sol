// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

contract Galeria {
    // Definir los atributos del contrato
    enum Estado {Creado, Iniciado, CerradoInscripciones, Juzgado, Inactivo}

    struct Obra {
        address artista; // Dirección del artista
        string nombre; // Nombre de la obra
        string url; // URL de la obra
        uint calificacion; // Calificación de la obra
        string comentario; // Comentario del crítico
        bool calificada; // Indica si la obra ha sido calificada
    }

    struct Ganador {
        address artista; // Dirección del artista
        string nombre; // Nombre de la obra
        uint premio; // Premio para la obra
        string comentario; // Comentario del crítico
    }

    Estado public estado; // Estado del contrato
    address public propietario; // Propietario del contrato
    address public critico; // Crítico de arte
    uint public valorBolsa; // Monto de la bolsa de premios
    uint public cuota; // Cuota de inscripción
    Obra[] public obras; // Lista de obras
    Ganador[] public ganadores; // Lista de ganadores

    constructor() payable {
        uint _valorBolsa = msg.value;
        require(_valorBolsa >= 1 ether && _valorBolsa <= 90 ether,
            "La bolsa de premios debe estar entre 1 y 90 Ethers"
        );
        propietario = msg.sender;
        valorBolsa = _valorBolsa;
        estado = Estado.Creado;
        cuota = _valorBolsa / 2;
    }

    modifier soloPropietario() {
        require(msg.sender == propietario, "Solo el propietario puede ejecutar esta funcion");
        _;
    }

    modifier soloCritico() {
        require(msg.sender == critico, "Solo el critico puede ejecutar esta funcion");
        _;
    }

    function asignarCritico(address _critico) public soloPropietario {
        require(estado == Estado.Creado, "El contrato debe estar en estado Creado");
        require(_critico != propietario, "El critico no puede ser el propietario");
        critico = _critico;
        estado = Estado.Iniciado;
    }

    function agregarObra(string memory _nombre, string memory _url) public payable {
        require(estado == Estado.Iniciado, "El contrato debe estar en estado Iniciado");
        require(msg.sender != propietario && msg.sender != critico, "El propietario y el critico no pueden participar como artistas");
        require(obras.length < 6, "El numero maximo de obras es 6");

        // Comprobar que la obra no haya sido agregada ya
        for (uint i = 0; i < obras.length; i++) {
            require(keccak256(abi.encodePacked(obras[i].url)) != keccak256(abi.encodePacked(_url)), "La obra ya ha sido agregada");
        }

        // Comprobar que el artista no esté participando ya con otra obra
        for (uint i = 0; i < obras.length; i++) {
            require(obras[i].artista != msg.sender, "El artista ya ha enviado una obra");
        }

        // Comprobar que la cuota de inscripción sea correcta
        require(msg.value == cuota, "La cuota de inscripcion debe ser la mitad de la bolsa de premios");

        // Agregar la obra a la lista
        obras.push(Obra(msg.sender, _nombre, _url, 0, "", false));
        valorBolsa += msg.value; // Añadir la cuota de inscripción a la bolsa de premios
    }

    function cerrarInscripciones() public soloPropietario {
        require(estado == Estado.Iniciado, "El contrato debe estar en estado Iniciado");
        require(obras.length >= 4, "El numero minimo de obras es 4");
        estado = Estado.CerradoInscripciones;
    }

    function verObras() public view soloCritico returns (string memory) {
        require(estado == Estado.CerradoInscripciones, "El contrato debe estar en estado CerradoInscripciones");
        string memory listaObras = "";
        for (uint i = 0; i < obras.length; i++) {
            listaObras = string(abi.encodePacked(
                listaObras, 
                "**Obra ", toString(i+1), "** ", 
                verObraParaCalificacion(i), 
                "-------------------" 
            ));
        }
        return listaObras;
    }



    function calificarObra(string memory _url, uint _calificacion, string memory _comentario) public soloCritico {
        require(estado == Estado.CerradoInscripciones, "El contrato debe estar en estado CerradoInscripciones");
        require(_calificacion >= 1 && _calificacion <= 10, "La calificacion debe estar entre 1 y 10");

        uint _indice = encontrarIndiceObraPorUrl(_url);
        require(_indice != type(uint).max, "Obra no encontrada");

        require(!calificacionTomada(_calificacion), "Otra obra ya tiene esta calificacion");

        Obra storage obra = obras[_indice];

        if (obra.calificada) {
            obra.calificacion = _calificacion; // Modificar calificación si la obra ya ha sido calificada
        } else {
            obra.calificacion = _calificacion;
            obra.comentario = _comentario;
            obra.calificada = true;
        }

        // Ordenar la lista de obras por calificación de mayor a menor
        for (uint i = _indice; i > 0 && obras[i].calificacion > obras[i - 1].calificacion; i--) {
            Obra memory temp = obras[i];
            obras[i] = obras[i - 1];
            obras[i - 1] = temp;
        }
    }

    // Función auxiliar para encontrar el índice de una obra basada en la URL
    function encontrarIndiceObraPorUrl(string memory _url) internal view returns (uint) {
        for (uint i = 0; i < obras.length; i++) {
            if (keccak256(abi.encodePacked(obras[i].url)) == keccak256(abi.encodePacked(_url))) {
                return i;
            }
        }
        return type(uint).max; // Retorna el valor máximo de uint si no se encuentra la obra
    }

    // Función auxiliar para comprobar si la calificación ya ha sido asignada a otra obra
    function calificacionTomada(uint _calificacion) internal view returns (bool) {
        for (uint i = 0; i < obras.length; i++) {
            if (obras[i].calificacion == _calificacion) {
                return true;
            }
        }
        return false;
    }

    function terminarCalificacion() public soloCritico {
        require(estado == Estado.RegistroCerrado, "El contrato debe estar en estado RegistroCerrado");

        // Comprobar que todas las obras han sido calificadas
        for (uint i = 0; i < obras.length; i++) {
            require(obras[i].calificada == true, "No todas las obras han sido calificadas");
        }

        estado = Estado.Juzgado;
    }

    function terminarConcurso() public payable soloPropietario {
        require(estado == Estado.Juzgado, "El contrato debe estar en estado Juzgado");

        // Calcular premios
        uint premio1 = valorBolsa / 2;
        uint premio2 = valorBolsa / 4;
        uint premio3 = valorBolsa / 10;
        uint premioCritico = valorBolsa - premio1 - premio2 - premio3;

        // Agregar ganadores a la lista
        ganadores.push(Ganador(obras[0].artista, obras[0].nombre, premio1, obras[0].comentario));
        ganadores.push(Ganador(obras[1].artista, obras[1].nombre, premio2, obras[1].comentario));
        ganadores.push(Ganador(obras[2].artista, obras[2].nombre, premio3, obras[2].comentario));

        // Transferir premios
        payable(obras[0].artista).transfer(premio1);
        payable(obras[1].artista).transfer(premio2);
        payable(obras[2].artista).transfer(premio3);
        payable(critico).transfer(premioCritico);

        estado = Estado.Inactivo;
    }

    function verGanadores() public view returns (string memory) {
        require(estado == Estado.Inactivo, "El contrato debe estar en estado Inactivo");
        string memory listaGanadores = "";
        for (uint i = 0; i < ganadores.length; i++) {
            listaGanadores = string(abi.encodePacked(
                listaGanadores, 
                "**Ganador ", toString(i+1), "** ", 
                verGanador(i), 
                "-------------------" 
            ));
        }
        return listaGanadores;
    }

    // Función interna para ver una obra con formato string para calificación
    function verObraParaCalificacion(uint indice) internal view returns (string memory) {
        require(indice < obras.length, "Indice fuera de limites");
        Obra memory obra = obras[indice];
        return string(abi.encodePacked(
            "Artista: ", toString(obra.artista), 
            "   Nombre: ", obra.nombre, 
            "   URL: ", obra.url, 
            "   Calificacion: ", toString(obra.calificacion), 
            "   Comentario: ", obra.comentario,
            "   "
        ));
    }

    //función interna para ver ganado con formato string
    function verGanador(uint indice) internal view returns (string memory) {
        require(indice < ganadores.length, "Indice fuera de limites");
        Ganador memory ganador = ganadores[indice];
        return string(abi.encodePacked(
            "Artista: ", toString(ganador.artista), 
            "   Nombre: ", ganador.nombre, 
            "   Premio: ", toString(ganador.premio), 
            "   Comentario: ", ganador.comentario,
            "   "
        ));
    }

    function toString(address account) internal pure returns (string memory) {
        return toAsciiString(account);
    }

    // Función para convertir un uint en string
    function toString(uint value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint temp = value;
        uint digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    // Función para convertir un bool en string
    function toString(bool value) internal pure returns (string memory) {
        return value ? "true" : "false";
    }

    // Función auxiliar para convertir una dirección en un string ASCII
    function toAsciiString(address x) internal pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint(uint160(x)) / (2 ** (8 * (19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2 * i] = char(hi);
            s[2 * i + 1] = char(lo);
        }
        return string(s);
    }

    function char(bytes1 b) internal pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }

}