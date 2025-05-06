import json

import streamlit as st
import sys
import os
from datetime import datetime, timezone
import asyncio
from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase
from bson import ObjectId
from openai import AsyncOpenAI
from dotenv import load_dotenv
import time
import httpx
from pydantic import BaseModel
from pymongo import MongoClient
import uuid
from typing import List, Dict, Any

# 添加后端目录到Python路径
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

# 加载环境变量
load_dotenv()

# 初始化OpenAI客户端
client = AsyncOpenAI(api_key=os.getenv("OPENAI_API_KEY"))

# 创建事件循环
loop = asyncio.new_event_loop()
asyncio.set_event_loop(loop)

# 初始化MongoDB客户端
MONGO_URL = os.getenv("MONGODB_URL", "mongodb://localhost:27017")
mongo_client = AsyncIOMotorClient(MONGO_URL, io_loop=loop)
db: AsyncIOMotorDatabase = mongo_client.dailymind
affirmations = db.affirmations
white_noises = db.white_noises
categories = db.categories
modules = db.modules  # 新增模块集合


class Affirmation(BaseModel):
    count: int
    contents: List[str]


# 定义助手函数
def run_async(coro):
    """运行异步函数的辅助函数"""
    return loop.run_until_complete(coro)


# 创建静态文件目录
static_dir = os.path.join(os.path.dirname(__file__), "static")
os.makedirs(static_dir, exist_ok=True)

# 创建音频文件目录
AUDIO_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "audio")
os.makedirs(AUDIO_DIR, exist_ok=True)


async def check_duplicate_affirmation(message: str) -> bool:
    """检查金句是否重复"""
    existing = await affirmations.find_one({"message": message})
    return existing is not None


async def generate_affirmations(module: str, category: str, lang: str, count: int = 15) -> list:
    """使用OpenAI批量生成金句，支持多语言"""
    prompt_dict = {
        "zh": f"""请生成{count}句关于{category}的正向赋能内容，包含：
1. 原创肯定宣言（建议使用「你/我」人称增强代入感）
2. 名人金句（需标注作者）
3. 经典书摘（需标注书名-作者）
4. 生活哲理短句（可融入自然意象或日常场景）

创作要求：
1. 单句精简有力，具备情绪提振效果
2. 省略所有标点符号
3. 每句独立成行
4. 内容不重复、类型不单一
5. 不添加任何编号
6. 名言/书摘需在句末用括号标注来源（例：(作者名) 或 (书名-作者名)）
7. 融合比喻/感官词汇（如「光」「种子」「破土」）增强画面感
8. 确保出处真实、语义积极
9. 单句长度不限，可根据情感表达需要调整，短至词群长至复合句，但需保持语义完整度与节奏感

示例范式：
你天生拥有穿越迷雾的勇气
困境是成长埋下的伏笔
"生命不是等待暴风雨过去，而是学会在雨中起舞" - 薇尔莉特·法兰克
"世界上只有一种真正的英雄主义，就是看清生活的真相后依然热爱它" -《米开朗基罗传》-罗曼·罗兰
""",
        "en": f"""Please generate {count} positive and empowering contents about {category}, including:
1. Original affirmations (recommend using "you/I" for personal touch)
2. Famous quotes (with author credit)
3. Book excerpts (with title - author)
4. Life philosophy phrases (incorporate natural imagery or daily scenarios)

Creation rules:
1. Each sentence concise, powerful, and mood-lifting
2. No punctuation marks allowed
3. Single sentence per line
4. Diverse content, no repetition
5. No numbering or ordering
6. Cite sources in parentheses for quotes/excerpts (e.g., (Author) or (Title - Author))
7. Include metaphors/sensory words (e.g., "light", "seed", "germinate") for vividness
8. Ensure authentic sources and positive connotations
9. Sentence length is unrestricted—from phrase-length to complex sentences—adjusted to emotional expression, while maintaining semantic coherence and rhythm

Example format:
You were born with the courage to traverse fog
Challenges are seeds of growth buried deep
"Life isn't about waiting for the storm to pass, it's about learning to dance in the rain" - Vivian Greene
"There is only one heroism in the world: to see the world as it is and to love it" - The Lives of the Masters - Romain Rolland
""",
        "ja": f"""{category}に関する前向きなエンパワーメントコンテンツを{count}文生成してください。内容は以下を含みます：
1. オリジナルアファーム（「あなた/私」人称を使用して代入感を高めること）
2. 著名人の名言（著者名を明記）
3. 書籍の抜粋（書名-著者名を明記）
4. 生活哲学の短フレーズ（自然イメージや日常場面を取り入れること）

作成要件：
1. 一文ずつがシンプルでパワフル、気持ちを高める効果があること
2. すべての句読点を省略すること
3. 1文ずつ独立して行に記載すること
4. 内容の重複なく、タイプを多様化すること
5. いかなる番号も付けないこと
6. 名言/書摘は文末に括弧で出典を記載（例：(著者名) または (書名-著者名)）
7. 比喩/感覚語（例：「光」「種」「芽吹く」）を取り入れ、イメージを鮮明にすること
8. 出典の真実性と内容の前向きさを確保すること
9. 文の長さは制限なく、フレーズから複合文まで、情感表現に合わせて調整可能だが、語義の一貫性とリズム感を維持すること

例の形式：
あなたには霧を抜ける勇気が天生で備わっている
困難は成長のために埋められた種だ
「人生は嵐が過ぎ去るのを待つことではなく、雨中でダンスをすることを学ぶことだ」 - ヴィヴィアン・グリーン
「世界にただ一つの英雄主義しかない。それは世界をそのまま見つめ、それを愛することだ」 - 巨匠の生涯 - ロマン・ロラン
"""
    }

    system_dict = {
        "zh": "你是国际认证的正念导师兼创意文案师，擅长将积极心理学与生活哲学转化为直击人心的短文案。精通从东西方经典著作、心理学理论及自然智慧中提炼金句，善于用「感官化表达 + 成长型思维」创作既能理性共鸣又能感性触动的内容。所有生成的内容前缀不要有任何列表符号",
        "en": "You are a certified mindfulness coach and creative copywriter, expert in transforming positive psychology and life philosophy into heart-striking short copies. Proficient in extracting golden phrases from classic works, psychological theories, and natural wisdom, adept at using'sensory expression + growth mindset' to create content that resonates both rationally and emotionally. All generated content should not have any list symbols at the prefix",
        "ja": "あなたは国際認定のマインドフルネスインストラクター兼クリエイティブコピーライターです。積極心理学と生活哲学を心に響く短いコンテンツに変換することが得意です。東西の古典作品、心理学理論、自然の知恵から金言を抽出することに精通し、「感覚的表現 + 成長型マインドセット」を用いて、理性的に共感でき感性的に触れるコンテンツを作成することができます。生成されるすべてのコンテンツの接頭辞にリスト記号を一切使用しないでください"
    }

    module_db = await db.modules.find_one({"_id": ObjectId(module)}) if module else None
    module_name = module_db["name"] if module_db else "General"
    print(f"module_name: {module_name}, module: {module}")
    if module_name == "圣经":
        print("生成圣经经文")
        prompt_dict = {
            "zh": f"""请生成{count}条与"{category}"主题深度关联的圣经经文，包含：
1. 新约核心经文（含保罗书信/公教会书信）
2. 旧约叙事性经文（含律法书/历史书/智慧书）
3. 四福音书具象化经文（马太/马可/路加/约翰）
4. 诗篇灵修经文与箴言智慧金句

创作要求：
1. 每条经文需体现主题在「救赎历史」「生命实践」「属灵真理」三维度的启示
2. 严格遵循和合本圣经原文，引用包含完整书名（使用规范译名）、章、节
3. 单句独立成行，采用「经文内容」—— 书名 章:节 格式
4. 确保跨新旧约、跨书卷的多样性（同书卷不超过2条）
5. 优先选择含具象场景（如旷野、葡萄园、殿宇）或隐喻意象（如灯、杖、吗哪）的经文
6. 福音书经文需包含耶稣具体教导或事迹场景
7. 诗篇经文侧重灵修共鸣，箴言侧重生活智慧指引

示例格式：
"我靠着那加给我力量的，凡事都能做" —— 腓立比书 4:13
"你们要给人，就必有给你们的" —— 路加福音 6:38
"惟喜爱耶和华的律法，昼夜思想，这人便为有福" —— 诗篇 1:2
"敬畏耶和华是智慧的开端，认识至圣者便是聪明" —— 箴言 9:10
""",
            "en": f"""Please generate {count} english Bible verses deeply related to the theme of "{category}", including:
1. Key New Testament verses (including Pauline Epistles/General Epistles)
2. Narrative Old Testament verses (including Law/History/Wisdom books)
3. Gospel verses (Matthew/Mark/Luke/John) with concrete imagery
4. Devotional Psalms and wisdom Proverbs

Creation rules:
1. Each verse should reflect the theme in three dimensions: redemptive history, life practice, spiritual truth
2. Strictly follow the Chinese Union Version (CUV) text, citing full book name (standard translation), chapter, verse
3. Single verse per line in format: "Verse content" — Book Chapter:Verse
4. Ensure diversity across OT/NT and different books (no more than 2 from the same book)
5. Prioritize verses with concrete scenes (wilderness, vineyard, temple) or metaphorical imagery (light, staff, manna)
6. Gospel verses must include specific teachings or narrative scenes of Jesus
7. Psalms focus on devotional resonance, Proverbs on practical wisdom

Example format:
"I can do all things through him who strengthens me" — Philippians 4:13
"Give, and it will be given to you" — Luke 6:38
"But his delight is in the law of the LORD, and on his law he meditates day and night" — Psalm 1:2
"The fear of the LORD is the beginning of wisdom, and the knowledge of the Holy One is insight" — Proverbs 9:10
""",
            "ja": f"""{category}のテーマと深く関連する聖書の節を{count}個生成してください。内容は以下を含みます：
1. 新約聖書の核心的節（パウロの書簡/公教会書を含む）
2. 旧約聖書の叙事的節（律法書/歴史書/智慧書を含む）
3. 四福音書の具象化された節（マタイ/マルコ/ルカ/ヨハネ）
4. 詩篇の瞑想的節と箴言の叡智の言葉

作成要件：
1. 各節はテーマを「救済史」「生活実践」「霊的真理」の三つの次元で反映すること
2. 和合本聖書の原文を厳密に従い、完全な書名（規範的和訳名）、章、節を含めること
3. 1節ずつ独立した行に記載し、「聖句の内容」ーー 書名 章:節 の形式を使用すること
4. 旧約・新約を跨いで異なる書物の多様性を確保すること（同じ書物からは2節まで）
5. 具体的場面（荒野、葡萄園、神殿）や比喩的イメージ（灯、杖、マナ）を含む節を優先すること
6. 福音書の節はイエスの具体的教えまたは出来事の場面を含めること
7. 詩篇の節は瞑想的共感を、箴言の節は生活的叡智を重点とすること

例：
「私は力を与えてくださる者に頼って、すべてのことができる」ーー ピリピ人への手紙 4:13
「あなたがたが与えれば、与えられるでしょう」ーー ルカの福音 6:38
「主の律法を喜び、昼夜それを思索する者は、幸福です」ーー 詩篇 1:2
「主を恐れることは知恵の始まりで、聖なる者を認識することは聡明です」ーー 箴言 9:10
"""
        }
        system_dict = {
            "zh": "你是拥有 20 年教牧经验的圣经学者，兼具解经家与灵修导师双重身份。擅长从经文历史背景（如创作时代、文化语境）与现代应用双重视角筛选经文，能精准把握主题在救赎史上的延续性启示。熟悉和合本圣经原文用词特点，善于提取含具象意象（如「酵」「窄门」「吗哪」）和叙事场景（如登山宝训、五饼二鱼）的经文，使古代真理在当代语境中产生灵性共鸣。所有生成的内容前缀不要有任何列表符号",
            "en": "You are a Bible scholar with 20 years of pastoral experience, combining the roles of exegete and spiritual mentor. Skilled in selecting verses from both historical context (composition era, cultural setting) and modern application perspectives, accurately grasping the theme's redemptive continuity. Familiar with the linguistic characteristics of CUV, adept at extracting verses with concrete imagery (yeast, narrow gate, manna) and narrative scenes (Sermon on the Mount, feeding of the five thousand), making ancient truths spiritually resonant in contemporary contexts. All generated content should not have any list symbols at the prefix",
            "ja": "あなたは 20 年間の教牧経験を持つ聖書学者で、解経家と瞑想導師の両方の役割を兼ね備えています。聖句の歴史的背景（創作時代、文化的文脈）と現代的適用の両方の視点から節を選択することが得意で、テーマの救済史的連続性を正確に把握することができます。和合本聖書の原文の用語特性に精通し、具象的なイメージ（「酵母」「狭い門」「マナ」）や叙事的場面（登山宝訓、五枚の小麦粉のパンと二匹の魚）を含む節を抽出することで、古代の真理が現代の文脈で霊的共感を生み出すようにします。生成されるすべてのコンテンツの接頭辞にリスト記号を一切使用しないでください"
        }

    elif module_name == "常识":
        print("生成常识")
        prompt_dict = {
            "zh": f"""请生成{count}条关于"{category}"主题的深度实用常识，涵盖：
1. 自然科学洞见（含物理/化学/生物等学科原理）
2. 生活策略方案（含家居管理/时间利用/消费决策等场景）
3. 健康管理体系（含生理健康/心理健康/营养学应用）
4. 历史脉络解析（含事件溯源/人物故事/文化演进）
5. 技术实践指南（含工具使用/技能养成/创新方法）

创作要求：
1. 每条常识需包含「核心原理+应用场景+价值点」三维要素
2. 融入具体数据（如研究年份、统计数字）或权威案例增强可信度
3. 采用「问题解决型」表述（如「如何应对…」「避免…的方法」）
4. 跨学科关联（如用物理学原理解释生活现象）
5. 提供细分场景适配方案（如家庭/职场/户外等不同场景）
6. 引用来源需标注具体研究成果或机构（例：(2023年《Nature》研究)）
7. 每类知识至少包含1条前沿科技或最新研究发现
8. 确保内容兼具知识性与趣味性（可加入冷知识或反常识观点）

示例格式：
冰箱冷冻室温度保持在-18℃可使食物保鲜期延长3倍，每降低1℃能耗增加5% (来源：中国标准化研究院)
用柠檬汁擦拭切菜刀可通过柠檬酸分解细菌，配合小苏打摩擦能去除刀面锈迹（酸碱中和原理）
2019年哈佛大学研究显示，每天步行6000步可降低40%心血管疾病风险，且碎片化步行同样有效
古埃及人用尼罗河水泛滥周期制定历法，这种天文历法比罗马历法早1600年（历史与天文学关联）
手机相机对焦时按住屏幕可锁定曝光值，在明暗变化场景中避免画面忽亮忽暗（技术操作指南）
""",
            "en": f"""Please generate {count} in-depth practical facts about "{category}", covering:
1. Natural science insights (physics/chemistry/biology principles)
2. Life strategy solutions (home management/time utilization/consumer decision-making)
3. Health management systems (physical/mental health/nutrition applications)
4. Historical context analysis (event origins, figure stories, cultural evolution)
5. Technical practice guides (tool usage, skill development, innovative methods)

Creation rules:
1. Each fact must include three elements: core principle, application scenario, value proposition
2. Incorporate specific data (research year, statistics) or authoritative cases for credibility
3. Use "problem-solving" phrasing (e.g., "How to handle...", "Methods to avoid...")
4. Interdisciplinary connections (e.g., explain life phenomena with physics principles)
5. Provide segmented scenario solutions (home/workplace/outdoor, etc.)
6. Cite specific research results or institutions (e.g., (2023 Nature study))
7. Each knowledge category includes at least 1 cutting-edge technology or latest finding
8. Ensure a balance of informativeness and趣味性 (include trivia or counterintuitive ideas)

Example format:
Maintaining a freezer at -18°C extends food freshness by 3 times, with each 1°C drop increasing energy consumption by 5% (Source: China National Institute of Standardization)
Wiping kitchen knives with lemon juice decomposes bacteria via citric acid, combined with baking soda friction to remove rust (acid-base neutralization principle)
A 2019 Harvard study shows 6,000 daily steps reduce cardiovascular risk by 40%, with fragmented walking equally effective
Ancient Egyptians developed a calendar based on Nile floods, 1,600 years earlier than the Roman calendar (history-astronomy connection)
Long-pressing the screen while focusing on a phone camera locks exposure, preventing brightness fluctuations in changing light (technical operation guide)
""",
            "ja": f"""{category}に関するディープな実用的な豆知識を{count}個生成してください。内容は以下をカバーします：
1. 自然科学的洞察（物理/化学/生物学などの学問の原理）
2. 生活戦略ソリューション（家事管理/時間活用/消費意思決定など）
3. 健康管理システム（生理的健康/心理的健康/栄養学の応用）
4. 歴史的文脈分析（出来事の起源、人物の物語、文化の進化）
5. 技術実践ガイド（ツールの使用、スキルの習得、革新的方法）

作成要件：
1. 各知識に「核心原理+適用場面+価値点」の三要素を含めること
2. 具体的なデータ（研究年、統計数値）または権威あるケースを組み込んで信頼性を高めること
3. 「問題解決型」表現を使用すること（例：「…に対処する方法」「…を避ける方法」）
4. 学際的な接続（例：物理学の原理を用いて生活現象を説明）
5. セグメント化されたシナリオソリューションを提供すること（家庭/職場/野外など）
6. 出典に具体的な研究成果または機関を明記すること（例：(2023年ネイチャー誌の研究)）
7. 各知識カテゴリーに少なくとも1つの最先端技術または最新の発見を含めること
8. 情報性と面白さのバランスを確保すること（トリビアまたは反通識的な観点を含める）

例：
冷蔵庫の冷凍庫を-18℃に保つと食品の鮮度が3倍延長され、1℃下げるごとに消費電力が5%増加する (出典：中国標準化研究院)
レモン汁で包丁を拭くとクエン酸によって細菌が分解され、小蘇打で摩擦すると刃物の錆を取り除くことができる（酸塩基中和の原理）
2019年のハーバード大学の研究によると、毎日6,000歩歩くと心血管疾患のリスクが40%低下し、断片的な散歩でも同様の効果がある
古代エジプト人はナイル川の氾濫周期に基づいて暦を作成し、この天文暦はローマ暦より1,600年前にできていた（歴史と天文学の接続）
スマートフォンのカメラでフォーカスする際に画面を長押しすると露出値が固定され、明暗の変化するシーンで画面の明るさのブレを防ぐことができる（技術操作ガイド）
"""
        }
        system_dict = {
            "zh": "你是拥有跨学科知识体系的实用知识架构师，擅长将自然科学原理、历史经验、技术方法整合成场景化解决方案。具备 10 年科普内容创作经验，熟悉《科学美国人》《Nature》等权威期刊的研究成果转化方法，能将前沿学术发现转化为易懂的生活应用指南。擅长在常识中融入「原理 - 应用 - 拓展」三层知识结构，使每条内容兼具基础实用性与深度思考价值。所有生成的内容前缀不要有任何列表符号",
            "en": "You are an interdisciplinary practical knowledge architect, skilled in integrating natural science principles, historical experience, and technical methods into scenario-based solutions. With 10 years of science communication experience, familiar with the research translation methods of authoritative journals like Scientific American and Nature, capable of transforming cutting-edge academic findings into understandable life guides. Proficient in embedding a 'principle-application-extension' three-layer structure in facts, ensuring each piece balances practical utility with deep thinking value. All generated content should not have any list symbols at the prefix",
            "ja": "あなたは学際的な知識体系を持つ実用的な知識アーキテクトであり、自然科学の原理、歴史的経験、技術的方法をシナリオベースのソリューションに統合することが得意です。10 年間の科学普及コンテンツ作成経験があり、『サイエンティフィックアメリカン』『ネイチャー』などの権威ある学術誌の研究成果を応用可能な知識に変換する方法を熟知しています。各知識に「原理 - 応用 - 展開」の 3 層構造を組み込むことで、基礎的な実用性と深い思考価値の両方を兼ね備えたコンテンツを作成することができます。生成されるすべてのコンテンツの接頭辞にリスト記号を一切使用しないでください"
        }

    elif module_name == "情话":
        print("生成情话")
        prompt_dict = {
            "zh": f"""请生成{count}句关于"{category}"主题的高感染力浪漫情话，涵盖以下五种情感表达：
    - 直击心灵的告白誓言：适用于关键表白场景，打动对方心弦
    - 细腻温柔的日常情话：适合早安晚安或陪伴的温柔瞬间
    - 诗意唯美的情感隐喻：用自然或生活意象表达爱意
    - 充满安全感的承诺话语：传递坚定的陪伴和爱意
    - 俏皮甜蜜的互动情话：增进亲密氛围的轻松表达

    创作要求：
    - 每句融入「独特记忆点」「情感共鸣点」「专属承诺感」三要素
    - 表达具体可感，如"咖啡的温度" "月光的轨迹"等生活化意象
    - 呈现不同恋爱阶段（暧昧期/热恋期/稳定期）的情感浓度
    - 引用内容需注明出处，优先选择经典爱情文学
    - 避免使用陈词滥调（如"你是我的太阳"），鼓励创新表达
    - 所有语句需自然流畅、富有画面感，并激发对方情感回应欲

    示例：
    你低头整理头发的样子，让我偷偷练习了无数次求婚誓词  
    和你走过的每条路，都成了我记忆里会发光的银河  
    "我曾踏月而来，只因你在山中"——《山月》 席慕蓉  
    遇见你后，连天气预报都成了我想和你分享的浪漫  
    想把对你的喜欢，熬成清晨第一口温热的粥  
    """,
            "en": f"""Please generate {count} highly evocative romantic quotes about "{category}" covering the following tones:
    - Heart-striking vows for pivotal confessions
    - Tender and gentle expressions for daily moments like morning or night greetings
    - Poetic metaphors using nature or everyday imagery to express love
    - Reassuring words of commitment conveying unwavering companionship
    - Playful, sweet lines that enhance intimacy and interaction

    Writing guidelines:
    - Each quote should integrate a unique memory trigger, an emotional resonance point, and a sense of personal promise
    - Use vivid and tangible imagery like "the warmth of coffee" or "the path of moonlight"
    - Adapt emotional depth for different relationship stages (flirting, infatuation, long-term)
    - Clearly cite sources if quoting; prioritize classic love literature
    - Avoid clichés such as "You're my sunshine" and aim for creative originality
    - Lines should feel natural, cinematic, and invite emotional engagement

    Examples:
    The way you tuck your hair behind your ear makes me secretly rehearse marriage proposals over and over  
    Every street we've walked down has become a glowing galaxy in my memory  
    "I came by moonlight, for you dwell in the mountains" – *Mountain Moon*, Hsi-Mu Jung  
    Since meeting you, even the weather forecast feels like a romance I want to share  
    I want to simmer my affection for you into the first warm sip of morning porridge  
    """,
            "ja": f"""{category}をテーマにした心を打つロマンチックな愛の言葉を{count}個作成してください。以下のスタイルを含めてください：
    - 重要な告白にふさわしい、心に響く誓いの言葉
    - 朝や夜の挨拶、静かな時間に寄り添う優しい愛の言葉
    - 自然や日常のイメージを使った詩的で美しい比喩
    - 揺るぎない愛と安心感を伝える約束の言葉
    - 親密な雰囲気を高める、甘くて少しふざけた愛の表現

    創作の条件：
    - 各言葉には「ユニークな思い出のきっかけ」「共感できる感情」「個人的な約束感」の3つを含めること
    - 「コーヒーの温もり」「月光の軌跡」のように具体的な感覚を伴う表現を使用
    - 恋愛のステージ（曖昧な関係/熱愛期/安定期）に応じて感情の深さを調整
    - 引用する場合は明確な出典を記載し、古典恋愛文学を優先
    - 「あなたは私の太陽」などの陳腐な比喩は避け、独創的な表現を奨励
    - 読んだ相手が感情的に反応したくなるような表現を目指すこと

    例：
    あなたが髪をかき上げる姿を見るたびに、プロポーズの言葉を何度も心の中で練習してしまう  
    一緒に歩いた道のすべてが、私の記憶の中で輝く銀河になっていった  
    「私は月の光の中を、あなたが山の中にいるからとやってきた」——『山月』席慕蓉  
    あなたに出会ってから、天気予報さえもロマンスの一部に感じられるようになった  
    あなたへの想いを、朝一番のあたたかいお粥にゆっくり煮込んで届けたい  
    """
        }

        system_dict = {
            "zh": "你是拥有 15 年情感写作经验的畅销书作家，同时是国家认证的心理咨询师。擅长从心理学「情感依恋理论」出发，结合文学创作手法，根据不同恋爱场景（初次约会 / 周年纪念 / 异地恋）创作精准触达对方心理需求的情话。熟悉《霍乱时期的爱情》《简爱》等经典爱情文学的表达技巧，能够将「安全感建立」「情感共振」「亲密感升级」等专业理论转化为细腻动人的文字。所有生成的内容前缀不要有任何列表符号",
            "en": "You are a bestselling author with 15 years of experience in emotional writing and a certified counseling psychologist. Skilled at crafting love quotes that precisely meet psychological needs in different relationship scenarios (first date, anniversary, long-distance) by integrating attachment theory with literary techniques. Familiar with expressive skills from classic love literature like Love in the Time of Cholera and Jane Eyre, able to translate professional theories of'security building', 'emotional resonance', and 'intimacy enhancement' into delicate and touching words. All generated content should not have any list symbols at the prefix",
            "ja": "あなたは 15 年間の感情表現の執筆経験を持つベストセラー作家であり、国家認定のカウンセリング心理士でもあります。心理学の「愛着理論」に基づき、文学的な創作手法を組み合わせて、異なる恋愛シナリオ（初デート / 記念日 / 遠距離恋愛）に応じて相手の心理的ニーズに的確に応える愛の言葉を作成することが得意です。『コレラの時代の愛』『ジェーン・エア』などの古典的な恋愛文学の表現技法を熟知しており、「安心感の構築」「感情の共鳴」「親密感の向上」などの専門的な理論を繊細で感動的な文章に変換することができます。生成されるすべてのコンテンツの接頭辞にリスト記号を一切使用しないでください"
        }

    elif module_name == "佛经":
        print("生成佛经")
        prompt_dict = {
            "zh": f"""请生成{count}条与"{category}"主题相关的佛经经文与教导，内容涵盖：
- 原典经典节选（来自《金刚经》《心经》《法华经》等佛教重要经藏）
- 禅宗祖师公案与开示（如六祖慧能、临济义玄、赵州从谂等祖师大德）
- 近现代高僧法语（如太虚大师、印光法师、星云大师等）
- 佛教基础教义与智慧讲解（四圣谛、八正道、十二因缘等核心法义）
- 禅修与日常观照引导（将佛法智慧融入日用即道的生活实践）

创作要求：
- 每条内容需具备「经文原文 + 通俗译解 + 当代应用」三重结构
- 引用原文时需准确注明出处（经名、品名或章节）
- 译解以现代白话表达，避免晦涩术语
- 内容紧扣主题，结合现实情境引导内心观照
- 体现无常、无我、缘起等佛法核心义理
- 禅宗公案需简述背景及智慧启示
- 应用部分具体实用，指导日常止烦修心
- 语言兼具佛法庄严与慈悲亲和

示例格式：
"诸行无常，是生灭法，生灭灭已，寂灭为乐" ——《涅槃经》  
译：一切现象皆在生灭变化中，放下执着才能契入寂灭之乐。  
用：观照人生起伏时，生起出离心与平等心。

"心如工画师，能画诸世间，五蕴悉从生，无法而不造" ——《华严经》  
译：万法由心所造，心念清净则外境自在。  
用：面对纷繁世界时，内观心念以净化外境。

六祖慧能云："菩提本无树，明镜亦非台，本来无一物，何处惹尘埃"  
译：直指心性本空，破除一切相执。  
用：烦恼时放下分别心，回归当下清净本心。
""",
            "en": f"""Please generate {count} Buddhist scriptures and teachings related to "{category}", covering:
- Original excerpts (Diamond Sutra, Heart Sutra, Lotus Sutra, etc.)
- Zen koans (from masters like Huineng, Linji, Zhaozhou)
- Modern teachings (Master Taixu, Yinguang, Hsing Yun, etc.)
- Core doctrines (Four Noble Truths, Eightfold Path, Twelve Links)
- Daily mindfulness guidance (integrating Dharma into daily life)

Requirements:
- Each entry includes "original text + plain interpretation + modern application"
- Cite clear sources (sutra name, chapter)
- Use accessible language, avoid jargon
- Relate abstract wisdom to real-life scenarios
- Reflect core concepts: impermanence, non-self, emptiness, etc.
- Brief context for koans with key insights
- Practical application for daily anxiety relief
- Tone: solemn yet compassionate

Example format:
"All conditioned things are impermanent; they arise and pass away. Ending birth and death brings nirvanic joy." —Nirvana Sutra  
Interp: Recognize impermanence to let go of clinging.  
Apply: Cultivate equanimity during life's changes.

"The mind is a painter, creating all worlds. The five aggregates arise from it." —Avatamsaka Sutra  
Interp: Outer reality mirrors inner consciousness.  
Apply: Purify mind to transform external experiences.

Sixth Patriarch Huineng: "Bodhi is no tree; the mirror is not a stand. Originally nothing exists—where can dust alight?"  
Interp: Pointing directly to the empty nature of mind.  
Apply: Release attachments to find clarity in distress.
""",
            "ja": f"""{category}に関連する仏教教えを{count}個生成してください。内容は以下を含む：
- 経典原文（『金剛経』『心経』『法華経』など）
- 禅師公案（慧能、臨済、趙州など）
- 現代高僧の法語（太虚、印光、星雲大師など）
- 基本教義（四諦、八正道、十二因縁など）
- 日常禅修指針（生活への実践応用）

作成要件：
- 各項目「原文 + 平易解釈 + 現代応用」の構成
- 出典を明記（経名・章）
- 解釈は難解な用語を避ける
- 教義を日常生活に結び付け
- 無常・無我・縁起などの核心を反映
- 公案には背景と啓示を簡述
- 応用部分は具体的で実践可能
- 言葉は厳かでありながら優しさを持つ

例：
「諸行無常、是生滅法、生滅滅已、寂滅為楽」——『涅槃経』  
解：あらゆるものは変化する。執着を捨てて安らぎを得る。  
用：人生の変化に平穏な心を保つときに想起する。

「心如工画師、能画諸世間、五蘊悉従生、無法而不造」——『華厳経』  
解：心が世界を創る。心を浄化すれば外境も浄化する。  
用：紛扰する日常で、内観を通じて心を整える。

慧能大師曰く：「菩提本無樹、明鏡亦非台、本来無一物、何処惹塵埃」  
解：心の本性は空で、執着は妄想である。  
用：煩悩の時、分別心を捨てて今の瞬間に戻る。
"""
        }
        system_dict = {
            "zh": "你是精通三藏十二部经典的佛学大德，兼具南传、北传、藏传三大传承的教法体系知识，有 20 年佛经教学与翻译经验。擅长以契理契机的方式，将深奥佛法智慧转化为现代人易于理解的语言。熟悉不同根器众生的理解能力，能将「缘起性空」「不垢不净」「诸法实相」等深奥义理，转化为接地气的生活指导。精通佛经梵文、巴利文和汉传经典之间的义理对照，能够准确传达佛陀本怀，同时不失现代表达的亲和力与可理解性。所有生成的内容前缀不要有任何列表符号",
            "en": "You are a Buddhist scholar versed in the Three Baskets and Twelve Divisions of Buddhist texts, knowledgeable in all three major traditions—Theravada, Mahayana, and Vajrayana—with 20 years of experience teaching and translating Buddhist scriptures. You excel at transforming profound Buddhist wisdom into language easily understood by contemporary people while remaining true to the original teachings. Familiar with the comprehension abilities of practitioners at different levels, you can translate deep concepts like 'dependent origination and emptiness,' 'neither defiled nor pure,' and 'true nature of all phenomena' into practical everyday guidance. Expert in comparative Buddhist theology across Sanskrit, Pali, and Chinese canonical texts, you accurately convey Buddha's original intent while maintaining modern expressiveness, approachability, and comprehensibility. All generated content should not have any list symbols at the prefix",
            "ja": "あなたは三蔵十二部の経典に精通した仏教学者であり、上座部、大乗、チベット仏教の三大伝統すべての教えに関する知識を持ち、20 年間の仏教経典の教授と翻訳の経験があります。深遠な仏教の智慧を現代人が理解しやすい言葉に変換することに長け、元の教えに忠実であり続けます。異なるレベルの修行者の理解力に精通し、「縁起と空性」「不垢不浄」「諸法実相」などの深い概念を日常的な実践的指導に翻訳することができます。サンスクリット語、パーリ語、中国語の正典テキスト間の比較仏教神学に精通し、現代的な表現力、親しみやすさ、理解しやすさを維持しながら、仏陀の本来の意図を正確に伝えることができます。生成されるすべてのコンテンツの接頭辞にリスト記号を一切使用しないでください"
        }

    elif module_name == "睡前故事":
        print("生成睡前故事")
        prompt_dict = {
            "zh": f"""请创作{count}个关于"{category}"主题的高质量睡前故事，每个故事需要：

1. 故事长度适中（400-600字），适合大约3-10分钟的朗读时间
2. 情节简单但引人入胜，具有清晰的开始、发展和温暖的结尾
3. 使用丰富的感官描写和生动的比喻，唤起听众的想象力
4. 结尾温暖、平和，带来安全感，帮助人们轻松入睡
5. 保持故事节奏平缓，避免过于刺激或紧张的情节
6. 内容适合所有年龄段，无恐怖、暴力或复杂概念，适合不同人群：孩子、朋友、父母、长辈等
7. 语言简洁易懂，富有想象力，能够引发共鸣，让听众感到放松和安心

请确保每个故事独特、原创，风格温馨，能够自然引导听众进入梦乡。故事应充满温情与美好，带来心灵的慰藉和宁静。

每个故事标题请用【】括起来，风格温馨、富有诗意。多个故事使用列表输出。
""",
            "en": f"""Please create {count} high-quality bedtime stories based on the theme "{category}". Each story should:

1. Be of moderate length (around 400-600 words), suitable for about 3-10 minutes of reading aloud
2. Have a simple yet engaging plot with a clear beginning, development, and a warm ending
3. Use rich sensory descriptions and vivid metaphors to spark the listener's imagination
4. End with a warm, peaceful conclusion that provides a sense of safety and helps ease into sleep
5. Maintain a gentle story pace, avoiding overly刺激 or tense scenes
6. Be appropriate for all ages, free of horror, violence, or complex concepts, suitable for a diverse audience: children, friends, parents, elders, etc.
7. Use simple, understandable language that is imaginative and resonates emotionally, promoting relaxation and comfort

Ensure each story is unique and original, with a warm, comforting style that naturally guides the listener into a restful sleep. The stories should be filled with warmth and beauty, offering solace and tranquility to the heart.

Please title each story with【】, in a warm, poetic style. Output multiple stories as a list.
""",
            "ja": f""""{count}個の高品質な就寝前の物語を、「{category}」のテーマに基づいて作成してください。各物語は：

1. 適度な長さ（約400〜600語）、朗読に約3〜10分かかるくらいの長さにしてください
2. シンプルでありながら引き込まれるストーリーで、明確な始まり、展開、温かい結末を持つこと
3. 豊かな感覚描写と生き生きとした比喩を用いて、聞き手の想像力をかき立てる
4. 温かく平和な結末で、安心感をもたらし、自然に眠りにつけるようにしてください
5. ゆったりとしたリズムで進行し、刺激的または緊張感のある場面を避ける
6. すべての年齢層に適し、恐怖や暴力、複雑な概念を含まず、子供から大人まで幅広く楽しめる内容にしてください
7. 簡潔で理解しやすい言葉を使い、想像力を刺激しながら、リラックスと安心感を促す

各物語はユニークでオリジナルなものであり、温かみのある優しいスタイルで、自然に聞き手を夢の世界へ導きます。物語は温もりと美しさに満ち、心の慰めと静けさをもたらすものにしてください。

各物語のタイトルは【】で囲み、温かく詩的なスタイルで表現してください。複数の物語をリスト形式で出力してください。
"""
        }
        system_dict = {
            "zh": "你是一位备受赞誉的文学作家，专门创作温馨、富有启发性的睡前故事。你擅长通过细腻的描写和温暖的语言，让每个故事既有娱乐性，又能带来心灵的平静和慰藉。你的故事适合所有年龄层，能帮助人们放松、安心地进入睡眠。",
            "en": "You are a highly acclaimed writer specializing in creating warm, inspiring bedtime stories. You excel at using delicate descriptions and gentle language to make each story both entertaining and soothing, helping listeners of all ages relax and peacefully fall asleep.",
            "ja": "あなたは高く評価されている作家であり、温かく、感動的な就寝前の物語を創作する専門家です。繊細な描写と優しい言葉を駆使し、すべての年齢層に楽しめる心安らぐ物語を作り出します。あなたの物語は、リラックスと安心感をもたらし、穏やかに眠りに誘います。"
        }
    prompt = prompt_dict.get(lang, prompt_dict["zh"])
    system_msg = system_dict.get(lang, system_dict["zh"])
    max_retries = 3
    retry_delay = 2  # 秒
    for attempt in range(max_retries):
        try:
            response = await client.chat.completions.parse(
                model="gpt-4.1",
                messages=[
                    {"role": "system", "content": system_msg},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.8,
                max_completion_tokens=4000,
                response_format=Affirmation
            )
            text = response.choices[0].message.content.strip()
            json_object = json.loads(text)
            affirmations_list = json_object["contents"]
            unique_affirmations = []
            for affirmation in affirmations_list:
                if not await check_duplicate_affirmation(affirmation):
                    unique_affirmations.append(affirmation)
            return unique_affirmations
        except Exception as e:
            if attempt < max_retries - 1:
                st.warning(f"生成失败，正在重试 ({attempt + 1}/{max_retries})... 错误信息: {str(e)}")
                await asyncio.sleep(retry_delay)
            else:
                st.error(f"生成金句失败: {str(e)}")
                return []


async def save_affirmations(messages: List[str], category: str, lang: str, module_id: str = None) -> int:
    """保存多条金句到数据库"""
    count = 0
    now = datetime.now(timezone.utc)
    for message in messages:
        # 检查是否已存在相同金句
        if not await check_duplicate_affirmation(message):
            doc = {
                "message": message,
                "category": category,
                "lang": lang,
                "module_id": module_id if module_id else None,
                "created_at": now,
                "is_active": True
            }
            await affirmations.insert_one(doc)
            count += 1
    return count


async def get_all_affirmations():
    """获取所有金句"""
    cursor = affirmations.find().sort("created_at", -1)
    return await cursor.to_list(length=None)


async def save_white_noise(file, name, category, module_id=None):
    """保存白噪音文件"""
    try:
        # 生成唯一文件名
        file_extension = os.path.splitext(file.name)[1]
        unique_filename = f"{uuid.uuid4()}{file_extension}"
        file_path = os.path.join(AUDIO_DIR, unique_filename)

        # 确保目录存在
        os.makedirs(os.path.dirname(file_path), exist_ok=True)

        # 保存文件
        with open(file_path, "wb") as f:
            f.write(file.getvalue())
            
        # 验证文件是否成功保存
        if not os.path.exists(file_path) or os.path.getsize(file_path) == 0:
            st.error(f"文件保存失败或为空: {file_path}")
            return False
            
        st.success(f"文件成功保存到: {file_path}")

        # 文件保存成功后，添加到数据库
        doc = {
            "name": name,
            "category": category,
            "module_id": module_id if module_id else None,
            "file_path": file_path,
            "created_at": datetime.now(timezone.utc),
            "updated_at": datetime.now(timezone.utc),
            "is_active": True
        }

        result = await white_noises.insert_one(doc)
        st.success(f"白噪音记录成功添加到数据库，ID: {result.inserted_id}")
        return True
    except Exception as e:
        st.error(f"保存白噪音失败: {str(e)}")
        # 如果文件已保存但数据库操作失败，删除文件
        if 'file_path' in locals() and os.path.exists(file_path):
            try:
                os.remove(file_path)
                st.info(f"已删除文件: {file_path}，因为数据库操作失败")
            except:
                pass
        return False


async def get_all_white_noises():
    """获取所有白噪音"""
    cursor = white_noises.find().sort("created_at", -1)
    return await cursor.to_list(length=None)


# 页面配置
st.set_page_config(
    page_title="DailyMind Admin",
    page_icon="🧠",
    layout="wide"
)

# 使用顶部导航替代侧边栏
st.markdown("""
<style>
    .stTabs [data-baseweb="tab-list"] {
        gap: 24px;
    }
    .stTabs [data-baseweb="tab"] {
        height: 50px;
        white-space: pre-wrap;
        font-size: 16px;
        font-weight: 500;
        padding: 10px 20px;
        border-radius: 5px;
    }
    .stTabs [aria-selected="true"] {
        background-color: rgba(128, 0, 128, 0.1);
    }
</style>
""", unsafe_allow_html=True)

tab1, tab2, tab3, tab4 = st.tabs(["模块管理", "分类管理", "金句管理", "白噪音管理"])


async def manage_modules():
    """模块管理功能"""
    # 添加新模块
    st.subheader("添加新模块")
    with st.form("add_module"):
        module_name = st.text_input("模块名称")
        submitted = st.form_submit_button("添加模块")

        if submitted and module_name:
            try:
                doc = {
                    "name": module_name,
                    "created_at": datetime.now(timezone.utc),
                    "updated_at": datetime.now(timezone.utc),
                    "is_active": True
                }
                await db.modules.insert_one(doc)
                st.success("模块添加成功！")
            except Exception as e:
                st.error(f"添加模块失败: {str(e)}")

    # 显示所有模块
    st.subheader("模块列表")
    modules_list = await db.modules.find().sort("created_at", -1).to_list(length=None)

    if not modules_list:
        st.info("暂无模块，请添加")

    for module in modules_list:
        with st.expander(f"{module['name']}"):
            col1, col2 = st.columns([3, 1])
            with col1:
                # 编辑模块
                with st.form(f"edit_module_{module['_id']}"):
                    new_name = st.text_input("模块名称", value=module['name'])
                    if st.form_submit_button("更新模块"):
                        try:
                            update = {
                                "name": new_name,
                                "updated_at": datetime.now(timezone.utc)
                            }
                            await db.modules.update_one(
                                {"_id": module["_id"]},
                                {"$set": update}
                            )
                            st.success("模块更新成功！")
                            st._rerun()
                        except Exception as e:
                            st.error(f"更新模块失败: {str(e)}")
            with col2:
                # 删除模块
                if st.button("删除", key=f"delete_module_{module['_id']}"):
                    try:
                        # 检查是否有关联数据
                        aff_count = await db.affirmations.count_documents({"module_id": str(module["_id"])})
                        cat_count = await db.categories.count_documents({"module_id": str(module["_id"])})

                        if aff_count > 0 or cat_count > 0:
                            st.warning(f"该模块下有关联数据，无法删除：金句({aff_count})、分类({cat_count})")
                        else:
                            await db.modules.delete_one({"_id": module["_id"]})
                            st.success("模块删除成功！")
                            st._rerun()
                    except Exception as e:
                        st.error(f"删除模块失败: {str(e)}")


with tab1:
    st.header("模块管理")
    run_async(manage_modules())

with tab2:
    st.header("分类管理")
    # 获取模块列表供选择
    modules_list = run_async(db.modules.find({"is_active": True}).sort("created_at", -1).to_list(length=None))
    modules_dict = {str(m["_id"]): m["name"] for m in modules_list}
    modules_dict[""] = "正念"  # 添加空选项

    # 添加新分类
    st.subheader("添加新分类")
    with st.form("add_category"):
        module_id = st.selectbox("所属模块", options=list(modules_dict.keys()), format_func=lambda x: modules_dict[x])
        name_zh = st.text_input("中文名称")
        name_en = st.text_input("英文名称")
        name_ja = st.text_input("日文名称")
        submitted = st.form_submit_button("添加分类")

        if submitted and name_zh and name_en and name_ja:
            try:
                doc = {
                    "name": {
                        "zh": name_zh,
                        "en": name_en,
                        "ja": name_ja
                    },
                    "module_id": module_id if module_id else None,
                    "created_at": datetime.now(timezone.utc),
                    "updated_at": datetime.now(timezone.utc),
                    "is_active": True
                }
                run_async(db.categories.insert_one(doc))
                st.success("分类添加成功！")
            except Exception as e:
                st.error(f"添加分类失败: {str(e)}")

    # 显示所有分类
    st.subheader("分类列表")
    categories = run_async(db.categories.find().sort("created_at", -1).to_list(length=None))

    for category in categories:
        module_name = modules_dict.get(category.get("module_id", ""), "正念")
        with st.expander(
                f"{category['name']['zh']} / {category['name']['en']} / {category['name']['ja']} ({module_name})"):
            col1, col2 = st.columns([3, 1])
            with col1:
                # 编辑分类
                with st.form(f"edit_category_{category['_id']}"):
                    new_module_id = st.selectbox(
                        "所属模块",
                        options=list(modules_dict.keys()),
                        format_func=lambda x: modules_dict[x],
                        key=f"module_{category['_id']}",
                        index=list(modules_dict.keys()).index(category.get("module_id", "")) if category.get(
                            "module_id", "") in modules_dict else 0
                    )
                    new_name_zh = st.text_input("中文名称", value=category['name']['zh'], key=f"zh_{category['_id']}")
                    new_name_en = st.text_input("英文名称", value=category['name']['en'], key=f"en_{category['_id']}")
                    new_name_ja = st.text_input("日文名称", value=category['name']['ja'], key=f"ja_{category['_id']}")
                    if st.form_submit_button("更新分类"):
                        try:
                            update = {
                                "name": {
                                    "zh": new_name_zh,
                                    "en": new_name_en,
                                    "ja": new_name_ja
                                },
                                "module_id": new_module_id if new_module_id else None,
                                "updated_at": datetime.now(timezone.utc)
                            }
                            run_async(db.categories.update_one(
                                {"_id": category["_id"]},
                                {"$set": update}
                            ))
                            st.success("分类更新成功！")
                            st._rerun()
                        except Exception as e:
                            st.error(f"更新分类失败: {str(e)}")
            with col2:
                # 删除分类
                if st.button("删除", key=f"delete_{category['_id']}"):
                    try:
                        run_async(db.categories.delete_one({"_id": category["_id"]}))
                        st.success("分类删除成功！")
                        st._rerun()
                    except Exception as e:
                        st.error(f"删除分类失败: {str(e)}")

with tab3:
    st.header("金句管理")
    # 获取模块列表和分类列表
    modules_list = run_async(db.modules.find({"is_active": True}).sort("created_at", -1).to_list(length=None))
    modules_dict = {str(m["_id"]): m["name"] for m in modules_list}
    modules_dict[""] = "正念"  # 添加空选项
    # 添加模块选择器
    selected_module = st.selectbox(
        "选择模块",
        options=list(modules_dict.keys()),
        format_func=lambda x: modules_dict[x],
        key="module_selector_affirmations"
    )
    # 获取所有分类
    query = {"is_active": True}
    if selected_module:
        # 如果选择了模块，获取该模块下的分类
        query["module_id"] = selected_module
    else:
        # 如果没有选择模块，获取没有module_id字段的分类
        query["$or"] = [
            {"module_id": None},
            {"module_id": {"$exists": False}}
        ]

    categories = run_async(db.categories.find(query).sort("created_at", -1).to_list(length=None))
    category_dict = {
        "zh": ["综合"] + [cat["name"]["zh"] for cat in categories],
        "en": ["All"] + [cat["name"]["en"] for cat in categories],
        "ja": ["総合"] + [cat["name"]["ja"] for cat in categories]
    }
    print(selected_module)
    print(categories)

    # 一键批量生成所有分类的多语言金句
    st.subheader("一键批量生成所有分类的多语言金句")
    if st.button("为所有分类批量生成多语言金句"):
        with st.spinner("正在为所有分类批量生成金句..."):
            langs = ["zh", "en", "ja"]
            total = 0
            for cat in categories:
                for lang in langs:
                    cat_name = cat["name"][lang]
                    st.write(f"正在生成：分类【{cat_name}】语言【{lang}】...")
                    messages = run_async(generate_affirmations(selected_module, cat_name, lang, 15))
                    if messages:
                        # 添加模块ID
                        count = run_async(save_affirmations(messages, cat_name, lang, selected_module))
                        st.success(f"分类【{cat_name}】语言【{lang}】生成并保存 {count} 条金句")
                        total += count
                    else:
                        st.warning(f"分类【{cat_name}】语言【{lang}】生成失败")
            st.success(f"全部分类多语言金句生成完毕！共生成 {total} 条。")

    # 录入新金句
    st.subheader("录入新金句")
    lang = st.selectbox("选择语言", ["zh", "en", "ja"], key="lang_input")
    category = st.selectbox("选择分类", category_dict[lang], key="cat_input")
    message = st.text_input("金句内容", key="msg_input")
    if st.button("保存金句"):
        if not message.strip():
            st.warning("金句内容不能为空！")
        else:
            doc = {
                "message": message.strip(),
                "lang": lang,
                "category": category,
                "module_id": selected_module if selected_module else None,
                "created_at": datetime.now(timezone.utc),
                "is_active": True
            }
            run_async(affirmations.insert_one(doc))
            st.success("金句保存成功！")

    # 批量生成金句
    st.subheader("批量生成金句（AI）")
    lang_gen = st.selectbox("选择生成语言", ["zh", "en", "ja"], key="lang_gen")
    category_gen = st.selectbox("选择生成分类", category_dict[lang_gen], key="cat_gen")
    count = st.slider("生成数量", min_value=1, max_value=15, value=5, step=1)
    if st.button("批量生成并保存金句"):
        with st.spinner("正在生成..."):
            messages = run_async(generate_affirmations(selected_module, category_gen, lang_gen, count))
            now = datetime.now(timezone.utc)
            for msg in messages:
                doc = {
                    "message": msg,
                    "lang": lang_gen,
                    "category": category_gen,
                    "module_id": selected_module if selected_module else None,
                    "created_at": now,
                    "is_active": True
                }
                run_async(affirmations.insert_one(doc))
            st.success(f"成功生成并保存 {len(messages)} 条金句（{lang_gen}）！")
            for msg in messages:
                st.write(msg)

    # 查询金句
    st.subheader("查询金句")
    lang_query = st.selectbox("查询语言", ["zh", "en", "ja"], key="lang_query")
    category_query = st.selectbox("查询分类", category_dict[lang_query], key="cat_query")
    if st.button("查询金句列表"):
        query = {"lang": lang_query, "category": category_query, "is_active": True}
        if selected_module:
            query["module_id"] = selected_module
        else:
            query["$or"] = [
                {"module_id": None},
                {"module_id": {"$exists": False}}
            ]
        docs = run_async(affirmations.find(query).sort("created_at", -1).to_list(length=50))
        st.write(f"共查询到 {len(docs)} 条金句：")
        for doc in docs:
            st.write(doc["message"])

    st.subheader("按条件删除金句")
    col1, col2, col3 = st.columns(3)

    with col1:
        # 模块选择
        module_to_delete = st.selectbox(
            "选择模块（必选）",
            options=list(modules_dict.keys()),
            format_func=lambda x: modules_dict[x],
            key="module_selector_delete"
        )

    with col2:
        # 分类选择（可选）
        category_to_delete = st.selectbox(
            "选择分类（可选）",
            options=[""] + [cat["name"]["zh"] for cat in categories],
            key="category_selector_delete"
        )

    with col3:
        # 语言选择（可选）
        lang_to_delete = st.selectbox(
            "选择语言（可选）",
            options=["", "zh", "en", "ja"],
            key="lang_selector_delete"
        )

    if st.button("删除符合条件的金句"):
        # 构建查询条件
        query = {"is_active": True}

        # 添加模块条件
        if module_to_delete:
            query["module_id"] = module_to_delete
        else:
            # 如果选择了正念模块（空字符串）
            query["$or"] = [
                {"module_id": None},
                {"module_id": {"$exists": False}}
            ]

        # 添加分类条件（如果选择了分类）
        if category_to_delete:
            query["category"] = category_to_delete

        # 添加语言条件（如果选择了语言）
        if lang_to_delete:
            query["lang"] = lang_to_delete

        # 执行删除操作
        try:
            result = run_async(affirmations.delete_many(query))
            st.success(f"已删除 {result.deleted_count} 条符合条件的金句！")
        except Exception as e:
            st.error(f"删除金句失败: {str(e)}")

    # 清空数据库
    if st.button("清空所有金句数据库（危险操作）"):
        result = run_async(affirmations.delete_many({}))
        st.success(f"已清空金句数据库，共删除 {result.deleted_count} 条记录！")

with tab4:
    st.header("白噪音管理")
    # 获取模块列表供选择
    modules_list = run_async(db.modules.find({"is_active": True}).sort("created_at", -1).to_list(length=None))
    modules_dict = {str(m["_id"]): m["name"] for m in modules_list}
    modules_dict[""] = "正念"  # 添加空选项

    # 上传新白噪音
    st.subheader("上传新白噪音")
    uploaded_file = st.file_uploader("选择音频文件")
    name = st.text_input("名称")
    category = st.selectbox("类别", ["自然", "环境", "冥想", "其他"])
    module_id = st.selectbox("所属模块", options=list(modules_dict.keys()), format_func=lambda x: modules_dict[x],
                             key="upload_module")

    if uploaded_file and name and st.button("上传"):
        with st.spinner("正在上传..."):
            if run_async(save_white_noise(uploaded_file, name, category, module_id)):
                st.success("白噪音上传成功！")

    # 显示所有白噪音
    st.subheader("白噪音列表")
    white_noises_list = run_async(get_all_white_noises())
    for white_noise in white_noises_list:
        module_name = modules_dict.get(white_noise.get("module_id", ""), "正念")
        col1, col2, col3, col4 = st.columns([2, 1, 1, 1])
        with col1:
            st.write(white_noise["name"])
        with col2:
            st.write(white_noise["category"])
        with col3:
            st.write(module_name)
        with col4:
            if st.button("删除", key=str(white_noise["_id"])):
                # 删除文件
                try:
                    os.remove(white_noise["file_path"])
                except:
                    pass
                # 删除记录
                run_async(white_noises.delete_one({"_id": white_noise["_id"]}))
                st._rerun()
