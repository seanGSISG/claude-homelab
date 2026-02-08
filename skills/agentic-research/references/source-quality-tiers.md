# Source Quality Tiers — Detailed Classification Guide

This reference provides detailed guidance on classifying sources into quality tiers for the agentic research system.

## Tier Definitions

### Tier 1: Primary Sources

**Definition:** Content created by the original author, creator, or organization being researched. First-hand accounts and original research.

**Characteristics:**
- Written by the framework/tool creator
- Official release announcements
- Original research with novel findings
- First-hand experience reports from practitioners
- Conference talks by project maintainers

**Examples:**
- Anthropic's blog post about Claude architecture
- LangChain creator's post about LangGraph design decisions
- Original arXiv paper introducing a new technique
- Founder's post-mortem on a production deployment

**Identification signals:**
- Author is affiliated with the project/organization
- Contains "we built", "we designed", "our approach"
- Published on the organization's official blog or site
- Contains novel data or findings not found elsewhere

---

### Tier 2: Academic Sources

**Definition:** Peer-reviewed or pre-print research from academic institutions, conference proceedings, and formal research publications.

**Characteristics:**
- Peer-reviewed journal articles
- Conference papers (NeurIPS, ICML, ACL, AAAI, etc.)
- arXiv pre-prints with institutional affiliation
- University research reports
- Thesis and dissertation work

**Examples:**
- arXiv paper on multi-agent coordination
- NeurIPS workshop paper on tool use in LLMs
- ACL paper on retrieval-augmented generation
- IEEE survey paper on agent architectures

**Identification signals:**
- Published on arxiv.org, ACM DL, IEEE Xplore, Springer
- Has abstract, methodology, results, references sections
- Authors have institutional affiliations
- Contains formal citation of related work

---

### Tier 3: Official Documentation

**Definition:** Official documentation, guides, and tutorials maintained by the project or organization.

**Characteristics:**
- API reference documentation
- Official getting-started guides
- Configuration and deployment guides
- Official tutorials and cookbooks
- GitHub READMEs from official repositories

**Examples:**
- docs.langchain.com documentation pages
- Official Anthropic API documentation
- readthedocs.io sites for open-source projects
- Official GitHub repository READMEs
- Swagger/OpenAPI specs

**Identification signals:**
- Hosted on the project's official domain
- Versioned and maintained alongside the codebase
- Contains API signatures, parameter descriptions
- Updated with each release

---

### Tier 4: Industry Analysis

**Definition:** Analysis, benchmarks, and commentary from recognized industry analysts and reputable technology publications.

**Characteristics:**
- Benchmark reports and comparisons
- In-depth technical analysis by respected engineers
- Industry survey results
- Reputable tech publication articles with analysis
- Expert commentary with evidence

**Examples:**
- Comprehensive framework comparison on a respected tech blog
- Benchmark results from a recognized evaluation platform
- Hacker News discussion with substantive expert analysis
- ThoughtWorks Technology Radar entries
- InfoQ architecture analysis articles

**Identification signals:**
- Author has demonstrated expertise (profile, other publications)
- Contains data, benchmarks, or evidence
- Published on a recognized platform
- Cites primary or academic sources

---

### Tier 5: Community Resources

**Definition:** Community-generated content including forum discussions, personal blogs, Stack Overflow answers, and social media threads.

**Characteristics:**
- Personal developer blog posts
- Stack Overflow questions and answers
- Reddit discussions (r/MachineLearning, r/LangChain, etc.)
- GitHub Issues and Discussions
- Dev.to and Medium personal articles

**Examples:**
- Developer's blog post about their experience with a framework
- Stack Overflow answer explaining a common pattern
- Reddit thread comparing approaches
- GitHub Discussion about best practices
- Medium article summarizing a technique

**Identification signals:**
- Published on personal blog or community platform
- Author may not have formal credentials
- Experience-based rather than research-based
- May lack formal citations

---

### Tier 6: News Sources

**Definition:** News articles, press releases, and general media coverage of technology topics.

**Characteristics:**
- Technology news site articles
- Press releases and announcements
- General media coverage
- Podcast transcripts (general audience)
- Newsletter summaries

**Examples:**
- TechCrunch article about a funding round
- The Verge coverage of a product launch
- VentureBeat summary of an AI trend
- Press release about a partnership

**Identification signals:**
- Published on a general news platform
- Focuses on "what happened" rather than "how it works"
- May lack technical depth
- Often derived from primary sources

---

## Prioritization Matrix

When the orchestrator must choose between sources for NotebookLM (limited to 300):

| Scenario | Preferred Tier | Rationale |
|----------|---------------|-----------|
| Technical accuracy needed | Official + Academic | Authoritative and verified |
| Understanding design decisions | Primary | Creator's own reasoning |
| Comparing approaches | Industry + Academic | Data-driven analysis |
| Practical implementation | Official + Community | How-to and real experience |
| Cutting-edge developments | Primary + Academic | Newest findings |
| Broad landscape overview | Industry + News | Wide coverage |

## Conflict Resolution

When sources from different tiers contradict each other:

1. **Higher tier wins by default** -- but document the contradiction
2. **Recency matters** -- newer Primary source may override older Academic source
3. **Never discard contradictions** -- always note both sides in findings
4. **Flag for orchestrator** -- let the synthesis phase resolve major contradictions
