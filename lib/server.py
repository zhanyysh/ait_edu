from flask import Flask, request, jsonify
import smtplib
import random
from email.mime.text import MIMEText

app = Flask(__name__)

# Временное хранилище кодов (в реальном приложении лучше использовать базу данных)
verification_codes = {}

@app.route('/send_verification_email', methods=['POST'])
def send_verification_email():
    data = request.get_json()
    email = data.get('email')
    
    if not email:
        return jsonify({'error': 'Email не указан'}), 400

    # Генерация 6-значного кода
    code = str(random.randint(100000, 999999))
    verification_codes[email] = code

    # Настройки SMTP для Gmail
    smtp_server = 'smtp.gmail.com'
    smtp_port = 587
    sender_email = 'your-email@gmail.com'  # Замените на ваш email
    sender_password = 'your-app-password'  # Замените на пароль приложения

    # Создание письма
    subject = 'Код подтверждения для регистрации'
    body = f'Ваш код подтверждения: {code}'
    msg = MIMEText(body)
    msg['Subject'] = subject
    msg['From'] = sender_email
    msg['To'] = email

    try:
        # Отправка письма через Gmail SMTP
        with smtplib.SMTP(smtp_server, smtp_port) as server:
            server.starttls()
            server.login(sender_email, sender_password)
            server.sendmail(sender_email, email, msg.as_string())
        return jsonify({'message': 'Код отправлен', 'code': code}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/verify_code', methods=['POST'])
def verify_code():
    data = request.get_json()
    email = data.get('email')
    code = data.get('code')

    if not email or not code:
        return jsonify({'error': 'Email или код не указаны'}), 400

    stored_code = verification_codes.get(email)
    if stored_code == code:
        del verification_codes[email]  # Удаляем код после успешной проверки
        return jsonify({'message': 'Код подтвержден'}), 200
    else:
        return jsonify({'error': 'Неверный код'}), 400

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)