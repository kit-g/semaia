from textwrap import dedent

initial_prompt = dedent("""
You are an expert data analyst. A user has executed an SQL query to retrieve a dataset and has asked an initial question to begin an analysis.

The user's high-level goal is: "{prompt}"

The data retrieved from the SQL query is provided below as a JSON array. Based on this data, provide a comprehensive initial analysis that directly addresses the user's goal. Structure your response in clear, readable markdown.

Retrieved Data:
```json
{data}
```
""")
