#include "spinlock_ece391.h"
#include "solution.h"
#include <bits/types.h>
  // Fill this out!!!

#define MAX_OCCUPANCY 20

void lab_init(ps_lock *lock) {
    spinlock_init_ece391(&(lock->lab_lock));
    lock->students_inside = 0;
    lock->tas_inside = 0;
    lock->professors_inside = 0;
}

void student_enter(ps_lock *lock) {
    while (1) {
        spinlock_lock_ece391(&(lock->lab_lock));

        // Check if professors are inside, and if so, wait
        if (lock->professors_inside > 0 || (lock->students_inside + lock->tas_inside) >= MAX_OCCUPANCY) {
            spinlock_unlock_ece391(&(lock->lab_lock));
            continue;
        }

        lock->students_inside++;
        spinlock_unlock_ece391(&(lock->lab_lock));
        break;
    }
}

void student_exit(ps_lock *lock) {
    spinlock_lock_ece391(&(lock->lab_lock));
    lock->students_inside--;
    spinlock_unlock_ece391(&(lock->lab_lock));
}

void ta_enter(ps_lock *lock) {
    while (1) {
        spinlock_lock_ece391(&(lock->lab_lock));

        // Check if professors are inside, and if so, wait
        if (lock->professors_inside > 0 || (lock->students_inside + lock->tas_inside) >= MAX_OCCUPANCY) {
            spinlock_unlock_ece391(&(lock->lab_lock));
            continue;
        }

        lock->tas_inside++;
        spinlock_unlock_ece391(&(lock->lab_lock));
        break;
    }
}

void ta_exit(ps_lock *lock) {
    spinlock_lock_ece391(&(lock->lab_lock));
    lock->tas_inside--;
    spinlock_unlock_ece391(&(lock->lab_lock));
}

void professor_enter(ps_lock *lock) {
    while (1) {
        spinlock_lock_ece391(&(lock->lab_lock));

        // Wait until no students or TAs are inside
        if (lock->students_inside > 0 || lock->tas_inside > 0) {
            spinlock_unlock_ece391(&(lock->lab_lock));
            continue;
        }

        lock->professors_inside++;
        spinlock_unlock_ece391(&(lock->lab_lock));
        break;
    }
}

void professor_exit(ps_lock *lock) {
    spinlock_lock_ece391(&(lock->lab_lock));
    lock->professors_inside--;
    spinlock_unlock_ece391(&(lock->lab_lock));
}
