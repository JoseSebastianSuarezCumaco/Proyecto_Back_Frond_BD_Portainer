package com.listatareas.backend.repository;

import com.listatareas.backend.entity.Task;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

// Repositorio de Task. Al extender JpaRepository ya tendremos
// operaciones básicas (guardar, buscar, eliminar) listas para usar
// cuando implementemos el servicio.
@Repository
public interface TaskRepository extends JpaRepository<Task, Long> {
}
