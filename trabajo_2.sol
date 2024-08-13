// SPDX-License-Identifier: GPL-3.0

/*
Inicialmente, el dueño de la galería crea un contrato inteligente en el cual deposita un valor en Ethers (un valor entero entre 1 y 90 Ethers). Este valor lo llamaremos valorbolsa.
El dueño de la galería queda establecido como el dueño del contrato. Cuando se crea el contrato, este queda en estado “Creado”.

*/


pragma solidity >=0.7.0 <0.8.0;

contract Concurso{
    address public owner;
    uint public valorbolsa;
    enum Estado {Creado, Iniciado, CerradoInscripciones, Juzgado, Inactivo}

    Estado public estado;

}
