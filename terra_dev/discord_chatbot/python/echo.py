from dotenv import dotenv_values
import discord
import re

class MyClient(discord.Client):
    async def on_ready(self):
        """
        Botが起動したときに呼び出される
        """
        # Logged on as {chat_bot_name}!
        print(f'Logged on as {self.user}!')

    async def on_message(self, message):
        """
        Botにメンションが送信されたときに呼び出される
        """
        # Message from seiwan_maikuma: <@1455022502169542964> hi
        print(f'Message from {message.author}: {message.content}')
        
        # Botが自分自身にメンションされているか確認
        if self.user.id not in [user.id for user in message.mentions]:
            return
        
        # <>で囲まれた部分（メンションなど）を除外
        cleaned_content = re.sub(r'<[^>]+>', '', message.content).strip()
        
        await message.channel.send(f"echoing: {cleaned_content}")

# Botの権限を設定
intents = discord.Intents.default()
intents.message_content = True

# .envは相対パスであるため、CWDはterraform/discord_chatbot/pythonになる必要がある
config = dotenv_values(".env")
token = config["DISCORD_BOT_TOKEN"]

client = MyClient(intents=intents)
client.run(token)