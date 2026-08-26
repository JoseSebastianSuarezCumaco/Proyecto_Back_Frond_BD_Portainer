import { Component, OnInit } from '@angular/core';
import { Task } from '../../models/task.model';
import { TaskService } from '../../services/task.service';

@Component({
  selector: 'app-task-list',
  templateUrl: './task-list.component.html',
  styleUrls: ['./task-list.component.css']
})
export class TaskListComponent implements OnInit {

  tasks: Task[] = [];
newTaskTitle = '';
backendStatus = '';

  constructor(private taskService: TaskService) {}

  ngOnInit(): void {
  }

  loadTasks(): void {
  this.backendStatus = 'Consultando backend...';

  this.taskService.getTasks().subscribe({
    next: (tasks) => {
      this.tasks = tasks;
      this.backendStatus = '✅ Backend conectado. Tareas consultadas correctamente.';
    },
    error: (error) => {
      console.error('Error al cargar las tareas:', error);
      this.backendStatus = '❌ Error al conectar con el backend.';
    }
  });
}

  addTask(): void {
    if (!this.newTaskTitle.trim()) {
      return;
    }

    const newTask: Task = {
      id: 0,
      title: this.newTaskTitle.trim(),
      completed: false
    };

    this.taskService.createTask(newTask).subscribe({
      next: () => {
        this.newTaskTitle = '';
      },
      error: (error) => {
        console.error('Error al crear la tarea:', error);
      }
    });
  }

  toggleTask(task: Task): void {
    const updatedTask: Task = {
      ...task,
      completed: !task.completed
    };

    this.taskService.updateTask(updatedTask).subscribe({
      next: () => {
        this.loadTasks();
      },
      error: (error) => {
        console.error('Error al actualizar la tarea:', error);
      }
    });
  }

  deleteTask(id: number): void {
    this.taskService.deleteTask(id).subscribe({
      next: () => {
        this.loadTasks();
      },
      error: (error) => {
        console.error('Error al eliminar la tarea:', error);
      }
    });
  }
}
