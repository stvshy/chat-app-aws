def lambda_handler(event, context):
    # Automatycznie potwierdzamy użytkownika
    event['response']['autoConfirmUser'] = True

    # Można też ustawić event['response']['autoVerifyEmail'] = True,
    # jeśli chcemy automatycznie weryfikować email
    return event
