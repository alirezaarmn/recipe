## Overview
These tests verify the `wait_for_db` Django management command, which waits for the database to be available (useful in Docker). The tests use mocking to simulate database states without a real connection.

>[!NOTE] 
> __call_command__ is Django built-in from `django.core.management` that used in tests to run management commands
> __wait_for_db__ is our custom command that we defined. command is used to make sure the db service is up and running before start the django.

## Command
We create `management` folder inside core app manually. The management folder is not built-in. Django discovers commands inside it if you follow the convention.
Once you create the folder structure, Django automatically:
- Scans all installed apps for `management/commands/` folders
- Django auto-discovers commands in `management/commands/` when a file defines a Command class extending `BaseCommand`
- Registers them as commands if they contain a Command class
- The command name comes from the filename (`wait_for_db.py` → `wait_for_db`)
Example: `call_command('wait_for_db')` runs the `wait_for_db` command. This is equivalent to running `python manage.py wait_for_db`

> [!WARNING]
>  the folder must be named management. Django's command discovery is hardcoded to look for `management/commands/` inside each app. It's not configurable.

## Step-by-Step Breakdown
### Lines 1-10: Imports and Setup
```python
from unittest.mock import patch
from psycopg2 import OperationalError as Psycopg2Error
from django.core.management import call_command
from django.db.utils import OperationalError
from django.test import SimpleTestCase
```
- `patch`: Mocks functions/methods during tests
- `Psycopg2Error`: PostgreSQL connection error
- `OperationalError`: Django database error
- `call_command`: Runs Django management commands in tests
- `SimpleTestCase`: Django test base class (no database)

### Line 16: Class-Level Mock Decorator
```python
@patch('core.management.commands.wait_for_db.Command.check')
class CommandTests(SimpleTestCase):
```
This is mocking the check method of BaseCommand. `Command` class in `commands/wait_for_db.py` extends it.

- decorator Mocks `Command.check` for all tests in the class
- `check` is a Django method that verifies database connectivity
- The mock is passed as `patched_check` to each test method

### Test 1: `test_wait_for_db_ready` (Lines 20-26)
```python
def test_wait_for_db_ready(self, patched_check):
    """Test waiting for database if database ready."""
    patched_check.return_value = True
    call_command('wait_for_db')
    patched_check.assert_called_once_with(databases=['default'])
```
`patched_check` is not a built-in variable. It's created by the `@patch` decorator and passed as a parameter to your test method.
- `@patch` replaces the real `Command.check` method with a mock object
- The decorator automatically passes the mock as a parameter to each test method
- The parameter name is up to you; here it's __patched_check__
- `patched_check`: the mock object created by `@patch`, passed automatically
- `patched_check.return_value = True`: Setting `return_value` makes the mock return that value when called. When `self.check(databases=['default')` runs, it calls the mock, which returns True
```
Real Code (wait_for_db.py):
┌─────────────────────────────────────┐
│ self.check(databases=['default'])   │  ← This is the REAL method
└─────────────────────────────────────┘
         ↓
    (Normally calls real database)

Test Code (test_commands.py):
┌─────────────────────────────────────┐
│ @patch('...Command.check')          │  ← Replaces real method
│ def test_wait_for_db_ready(         │
│     self, patched_check):           │  ← Mock object passed here
│     patched_check.return_value = True│ ← Mock returns True
└─────────────────────────────────────┘
         ↓
    (Now calls MOCK instead of real database)
```
- call the command
- Asserts check was called once with databases=['default']

**Why this test matters:** Verifies the happy path when the database is immediately available.

### Test 2: `test_wait_for_db_delay` (Lines 28-37)
```python
@patch('time.sleep')
def test_wait_for_db_delay(self, patched_sleep, patched_check):
    """Test waiting for database when getting OperationalError."""
    patched_check.side_effect = [Psycopg2Error] * 2 + [OperationalError] * 3 + [True]
    call_command('wait_for_db')
    self.assertEqual(patched_check.call_count, 6)
    patched_check.assert_called_with(databases=['default'])
```
- Mocks `time.sleep` to avoid real delays in tests
- The mock is passed as `patched_sleep` to the test method

> [!IMPORTANT] 
> ```
>@patch('time.sleep')
>def test_wait_for_db_delay(self, patched_sleep, patched_check)
>```
> Decorators are applied **bottom-to-top**, so parameters are passed right-to-left:
>- Rightmost parameter = innermost decorator (`@patch('time.sleep')`)
>- Leftmost parameter = outermost decorator (`@patch('...Command.check')`)

> [!NOTE]
> What `side_effect` does:
>
> - `side_effect` is different from `return_value`
> - `return_value`: always returns the same value
> - `side_effect`: can return different values or raise exceptions on each call

#### Line 27-28 `patched_check.side_effect = [Psycopg2Error] * 2 + [OperationalError] * 3 + [True]`

Breaking down the list:
```
[Psycopg2Error] * 2        # First 2 calls raise Psycopg2Error
+ [OperationalError] * 3   # Next 3 calls raise OperationalError  
+ [True]                   # 6th call returns True (success!)
```
Expanded list:
```
[
    Psycopg2Error,      # Call 1: raises exception
    Psycopg2Error,      # Call 2: raises exception
    OperationalError,   # Call 3: raises exception
    OperationalError,   # Call 4: raises exception
    OperationalError,   # Call 5: raises exception
    True                # Call 6: returns True (success!)
]
```

#### Line 30: Running the command
```
call_command('wait_for_db')
```
What happens inside the command (from `wait_for_db.py`):
```python
db_up = False
while db_up is False:              # Loop until database is ready
    try:
        self.check(databases=['default'])  # ← This calls patched_check!
        db_up = True               # Success! Exit loop
    except (Psycopg2OpError, OperationalError):
        self.stdout.write('Database unavailable, waiting 1 second...')
        time.sleep(1)              # ← This calls patched_sleep (mocked, no delay)
```
Execution flow:
```python
Attempt 1:
  patched_check() → raises Psycopg2Error
  → caught by except → sleep(1) → loop continues

Attempt 2:
  patched_check() → raises Psycopg2Error
  → caught by except → sleep(1) → loop continues

Attempt 3:
  patched_check() → raises OperationalError
  → caught by except → sleep(1) → loop continues

Attempt 4:
  patched_check() → raises OperationalError
  → caught by except → sleep(1) → loop continues

Attempt 5:
  patched_check() → raises OperationalError
  → caught by except → sleep(1) → loop continues

Attempt 6:
  patched_check() → returns True
  → no exception! → db_up = True → loop exits ✅
```

#### Line 32: Verifying call count
`self.assertEqual(patched_check.call_count, 6)`

#### Line 33: Verifying the final call
`patched_check.assert_called_with(databases=['default'])`