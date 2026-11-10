# Built-in Python libraries: nothing extra needs installing.
import json
import os
import smtplib
import ssl
import subprocess
from email.message import EmailMessage
from pathlib import Path


def send_email(subject, body):
    """Send an email to the Gmail account saved on this computer."""

    # Find Windows PowerShell on your computer.
    powershell = (
        Path(os.environ["SystemRoot"])
        / "System32/WindowsPowerShell/v1.0/powershell.exe"
    )

    # These PowerShell commands:
    # 1. Locate your encrypted credential file.
    # 2. Decrypt it using your Windows account.
    # 3. Return the email address and App Password as JSON.
    #
    # The r before the quotes preserves backslashes in Windows paths.
    command = r"""
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Find the credential file outside the GitHub project.
$path = Join-Path $env:LOCALAPPDATA "WorldBankPipeline\gmail-credential.xml"

# Load the credentials saved by this Windows account.
$credential = Import-Clixml -LiteralPath $path

# Return the credentials to Python.
@{
    email = $credential.UserName
    password = $credential.GetNetworkCredential().Password
} | ConvertTo-Json -Compress
"""

    # Run PowerShell from Python.
    # capture_output=True keeps its output out of the terminal.
    # The decrypted password is held in memory; do not print result.stdout.
    # timeout=15 prevents waiting indefinitely.
    result = subprocess.run(
        [
            str(powershell),
            "-NoProfile",
            "-NonInteractive",
            "-Command",
            command,
        ],
        capture_output=True,
        text=True,
        encoding="utf-8-sig",
        timeout=15,
        check=False,
    )

    # A return code of 0 means PowerShell succeeded.
    # Otherwise, stop with a helpful error.
    if result.returncode != 0:
        raise RuntimeError(
            "Could not read Gmail credentials. "
            "Use the Windows account that saved them."
        )

    # Convert the JSON text into a Python dictionary.
    credentials = json.loads(result.stdout)

    # Remove accidental spaces around the email address.
    address = credentials["email"].strip()

    # Google displays App Passwords in groups.
    # Remove any spaces copied between those groups.
    password = credentials["password"].replace(" ", "")

    # Build the email.
    # Sending to the same address means you receive your own alert.
    message = EmailMessage()
    message["From"] = address
    message["To"] = address
    message["Subject"] = subject
    message.set_content(body)

    # Connect securely to Gmail.
    # The SSL context checks the server's certificate.
    # timeout=20 limits how long network operations can wait.
    # The "with" block closes the connection when finished.
    with smtplib.SMTP_SSL(
        "smtp.gmail.com",
        465,
        context=ssl.create_default_context(),
        timeout=20,
    ) as server:

        # Sign in using your Gmail address and App Password.
        server.login(address, password)

        # Submit the email to Gmail for delivery.
        server.send_message(message)


# This block runs only when you run this file directly.
# Importing send_email into the pipeline will not send this test.
if __name__ == "__main__":
    try:
        # Send a simple test message.
        send_email(
            "World Bank Pipeline - Test Alert",
            "Your pipeline email helper is working.\n\n"
            "This is a test message. Automatic failure alerts "
            "have not been connected yet.",
        )

    except Exception as error:
        # Show only the error type, without printing credentials.
        # Exit code 1 tells the terminal that the test failed.
        print(f"Test email failed: {type(error).__name__}")
        raise SystemExit(1)

    # Gmail accepted the message, but check the inbox to confirm delivery.
    print("Test email accepted by Gmail. Check your inbox and spam folder.")